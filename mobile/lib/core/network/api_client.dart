import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/core/config/env.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/network/supabase_client_provider.dart';

/// Thin wrapper around [Dio] configured to talk to the FastAPI backend.
///
/// Every request carries the current Supabase session's access token as a
/// Bearer token. This is the core of the "Flutter -> FastAPI -> Supabase"
/// auth flow described in docs/ARCHITECTURE.md: Flutter never talks to
/// Postgres/Storage directly, it authenticates with Supabase and then calls
/// FastAPI with that token.
///
/// Session handling, in order:
///  1. No session yet (or already signed out): the request is NOT sent; it
///     fails locally with a 401 [ApiException]. Nothing protected ever goes
///     out before login has produced a session.
///  2. Session token expired (or about to): refreshed first, so the request
///     goes out with a valid token. Concurrent requests share one refresh.
///  3. Server still answers 401 (e.g. token revoked, clock skew): refresh
///     once and retry the request once.
///  4. Refresh impossible, or the retry is still 401: the session is dead,
///     so it's cleared locally. The router's auth gate then sends the user
///     back to Login (`core/routing/app_router.dart`) rather than leaving a
///     generic API error on screen.
class ApiClient {
  ApiClient({Dio? dio, GoTrueClient? auth})
      : _dio = dio ?? Dio(),
        _authOverride = auth {
    // Only set defaults for a client we built ourselves; an injected [Dio]
    // (tests) keeps its own base URL and adapter.
    if (dio == null) {
      _dio.options.baseUrl = Env.apiBaseUrl;
      _dio.options.connectTimeout = const Duration(seconds: 15);
      _dio.options.receiveTimeout = const Duration(seconds: 15);
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  static const _retriedKey = 'auth_retried';

  static const sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  final Dio _dio;
  final GoTrueClient? _authOverride;
  Future<Session?>? _refreshInFlight;

  GoTrueClient get _auth => _authOverride ?? Supabase.instance.client.auth;

  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters}) {
    return _send(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  /// [options] lets a caller override per-request settings such as timeouts
  /// (e.g. a multi-photo upload needs far longer than the 15s default).
  Future<Response<T>> post<T>(String path, {Object? data, Options? options}) {
    return _send(() => _dio.post<T>(path, data: data, options: options));
  }

  Future<Response<T>> delete<T>(String path) {
    return _send(() => _dio.delete<T>(path));
  }

  /// Surfaces failures as [ApiException] (which the interceptors always
  /// attach to the [DioException]) so callers and `ErrorView.forError` deal
  /// with one error type instead of digging through Dio internals.
  Future<Response<T>> _send<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      final inner = error.error;
      throw inner is ApiException
          ? inner
          : ApiException(
              message: error.message ?? 'Unexpected network error.',
              statusCode: error.response?.statusCode,
            );
    }
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final String? token;
    try {
      token = await _validAccessToken();
    } on AuthRetryableFetchException {
      // Couldn't reach Supabase to refresh: a connectivity problem, not a
      // dead session, so it must not log the user out.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const ApiException(
              message: 'Unable to reach the authentication service.'),
        ),
      );
      return;
    }
    if (token == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const ApiException(
              message: sessionExpiredMessage, statusCode: 401),
        ),
      );
      return;
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<void> _onError(
      DioException error, ErrorInterceptorHandler handler) async {
    if (error.error is ApiException) {
      handler.next(error); // already normalized (e.g. rejected in _onRequest)
      return;
    }
    if (error.response?.statusCode != 401) {
      handler.next(_normalize(error));
      return;
    }

    final request = error.requestOptions;
    if (request.extra[_retriedKey] == true) {
      // A freshly refreshed token was rejected too: the session is unusable.
      await _endSession();
      handler.next(_sessionExpired(error));
      return;
    }

    final Session? session;
    try {
      session = await _sessionForRetry(request.headers['Authorization']);
    } on AuthRetryableFetchException {
      handler.next(_normalize(error));
      return;
    }
    if (session == null) {
      await _endSession();
      handler.next(_sessionExpired(error));
      return;
    }

    request.extra[_retriedKey] = true;
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    // A multipart body is a one-shot stream; the retry needs a fresh copy.
    final body = request.data;
    if (body is FormData) request.data = body.clone();
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError); // already normalized by this same interceptor
    }
  }

  /// The access token to send right now, refreshing first if it's expired
  /// (or within seconds of expiring). Null means there is no usable session.
  Future<String?> _validAccessToken() async {
    var session = _auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) session = await _refreshSession();
    return session?.accessToken;
  }

  /// A session to retry a 401'd request with: whatever is current if it has
  /// already been rotated since the failed request went out (another
  /// request refreshed it), otherwise a freshly refreshed one.
  Future<Session?> _sessionForRetry(Object? sentAuthorization) async {
    final current = _auth.currentSession;
    if (current == null) return null;
    if (sentAuthorization != 'Bearer ${current.accessToken}') return current;
    return _refreshSession();
  }

  /// Refreshes the session, sharing one network call between concurrent
  /// callers (Supabase rotates refresh tokens, so parallel refreshes with
  /// the same token would invalidate each other). Returns null if the
  /// refresh token itself is no longer valid; rethrows
  /// [AuthRetryableFetchException] for plain connectivity failures.
  Future<Session?> _refreshSession() {
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<Session?> _doRefresh() async {
    try {
      final response = await _auth.refreshSession();
      return response.session;
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException {
      return null;
    }
  }

  Future<void> _endSession() async {
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Local state is cleared before any network call in signOut(), so a
      // failure reaching the server to revoke it doesn't change the outcome.
    }
  }

  DioException _sessionExpired(DioException error) {
    return error.copyWith(
      error:
          const ApiException(message: sessionExpiredMessage, statusCode: 401),
    );
  }

  DioException _normalize(DioException error) {
    final statusCode = error.response?.statusCode;
    final serverMessage = error.response?.data is Map
        ? (error.response?.data as Map)['detail']?.toString()
        : null;

    return error.copyWith(
      error: ApiException(
        message: serverMessage ?? error.message ?? 'Unexpected network error.',
        statusCode: statusCode,
      ),
    );
  }
}

/// Riverpod provider so the rest of the app injects [ApiClient] instead of
/// constructing it, which keeps it swappable in tests.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(auth: ref.watch(supabaseAuthProvider)),
);
