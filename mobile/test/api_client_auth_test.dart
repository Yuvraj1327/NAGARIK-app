import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/core/network/api_exception.dart';

/// A real-shaped (unsigned) JWT whose `exp` claim is [expiresIn] from now —
/// `Session.isExpired` only reads that claim.
String _jwt(Duration expiresIn, {String tag = 'a'}) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'ES256', 'typ': 'JWT'})}.${b64({
        'exp': exp,
        'tag': tag
      })}.sig';
}

Session _session(String accessToken) => Session(
      accessToken: accessToken,
      tokenType: 'bearer',
      refreshToken: 'refresh',
      user: const User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

/// Just the parts of GoTrueClient that ApiClient touches.
class _FakeAuth implements GoTrueClient {
  _FakeAuth(this.session);

  Session? session;
  int refreshCalls = 0;
  int signOutCalls = 0;
  Object? refreshError;
  Session? Function()? onRefresh;

  @override
  Session? get currentSession => session;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (refreshError != null) throw refreshError!;
    session = onRefresh!.call();
    return AuthResponse(session: session);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCalls++;
    session = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for FastAPI: 200 only for [validToken], 401 for anything else.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.validToken);

  String? validToken;
  final List<String?> seenAuthHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final header = options.headers['Authorization'] as String?;
    seenAuthHeaders.add(header);
    final ok = header == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode(ok
          ? {'id': 'user-1'}
          : {'detail': 'Invalid or expired authentication token.'}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient client, _FakeAuth auth, _FakeBackend backend}) _setup({
  required Session? session,
  required String? validToken,
}) {
  final auth = _FakeAuth(session);
  final backend = _FakeBackend(validToken);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
    ..httpClientAdapter = backend;
  return (
    client: ApiClient(dio: dio, auth: auth),
    auth: auth,
    backend: backend
  );
}

void main() {
  test('attaches the current session token as a Bearer header', () async {
    final token = _jwt(const Duration(hours: 1));
    final t = _setup(session: _session(token), validToken: token);

    final response = await t.client.get<Map<String, dynamic>>('/users/me');

    expect(response.statusCode, 200);
    expect(t.backend.seenAuthHeaders, ['Bearer $token']);
    expect(t.auth.refreshCalls, 0);
  });

  test('sends nothing before a session exists', () async {
    final t = _setup(session: null, validToken: 'x');

    await expectLater(
      t.client.get<dynamic>('/users/me'),
      throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(t.backend.seenAuthHeaders, isEmpty);
    expect(t.auth.signOutCalls, 0);
  });

  test('refreshes an expired token before sending the request', () async {
    final fresh = _jwt(const Duration(hours: 1), tag: 'fresh');
    final t = _setup(
        session: _session(_jwt(const Duration(minutes: -5))),
        validToken: fresh);
    t.auth.onRefresh = () => _session(fresh);

    final response = await t.client.get<dynamic>('/users/me');

    expect(response.statusCode, 200);
    expect(t.auth.refreshCalls, 1);
    expect(
        t.backend.seenAuthHeaders, ['Bearer $fresh']); // stale token never sent
  });

  test('concurrent requests share a single refresh', () async {
    final fresh = _jwt(const Duration(hours: 1), tag: 'fresh');
    final t = _setup(
        session: _session(_jwt(const Duration(minutes: -5))),
        validToken: fresh);
    t.auth.onRefresh = () => _session(fresh);

    await Future.wait([
      t.client.get<dynamic>('/users/me'),
      t.client.get<dynamic>('/reports'),
      t.client.get<dynamic>('/reports', queryParameters: {'mine': true}),
    ]);

    expect(t.auth.refreshCalls, 1);
  });

  test('a 401 triggers one refresh and one retry that succeeds', () async {
    final stale = _jwt(const Duration(hours: 1), tag: 'stale');
    final fresh = _jwt(const Duration(hours: 1), tag: 'fresh');
    final t = _setup(session: _session(stale), validToken: fresh);
    t.auth.onRefresh = () => _session(fresh);

    final response = await t.client.get<dynamic>('/users/me');

    expect(response.statusCode, 200);
    expect(t.backend.seenAuthHeaders, ['Bearer $stale', 'Bearer $fresh']);
    expect(t.auth.refreshCalls, 1);
    expect(t.auth.signOutCalls, 0);
  });

  test(
      'a 401 that survives the retry signs the user out with a session-expired error',
      () async {
    final t = _setup(
        session: _session(_jwt(const Duration(hours: 1))),
        validToken: 'never-valid');
    t.auth.onRefresh =
        () => _session(_jwt(const Duration(hours: 1), tag: 'fresh'));

    await expectLater(
      t.client.get<dynamic>('/users/me'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having(
                (e) => e.message, 'message', ApiClient.sessionExpiredMessage),
      ),
    );
    expect(t.backend.seenAuthHeaders.length, 2); // original + exactly one retry
    expect(t.auth.signOutCalls, 1);
  });

  test('an unrecoverable refresh token signs the user out', () async {
    final t = _setup(
        session: _session(_jwt(const Duration(hours: 1))),
        validToken: 'never-valid');
    t.auth.refreshError =
        AuthApiException('Invalid Refresh Token', statusCode: '400');

    await expectLater(
      t.client.get<dynamic>('/users/me'),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'message', ApiClient.sessionExpiredMessage)),
    );
    expect(t.auth.signOutCalls, 1);
  });

  test('a connectivity failure during refresh does NOT sign the user out',
      () async {
    final t = _setup(
        session: _session(_jwt(const Duration(minutes: -5))), validToken: 'x');
    t.auth.refreshError = AuthRetryableFetchException(message: 'offline');

    await expectLater(
      t.client.get<dynamic>('/users/me'),
      throwsA(isA<ApiException>()
          .having((e) => e.isNetworkError, 'isNetworkError', true)),
    );
    expect(t.auth.signOutCalls, 0);
    expect(t.backend.seenAuthHeaders, isEmpty);
  });

  test('non-401 server errors surface the server message and keep the session',
      () async {
    final token = _jwt(const Duration(hours: 1));
    final t = _setup(session: _session(token), validToken: token);
    t.backend.validToken = null;
    // Reuse the fake but make it return 500 for this one.
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter =
          _StatusBackend(500, {'detail': 'Internal server error.'});
    final client = ApiClient(dio: dio, auth: t.auth);

    await expectLater(
      client.get<dynamic>('/reports'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'Internal server error.'),
      ),
    );
    expect(t.auth.signOutCalls, 0);
    expect(t.auth.refreshCalls, 0);
  });
}

class _StatusBackend implements HttpClientAdapter {
  _StatusBackend(this.status, this.body);

  final int status;
  final Map<String, Object?> body;

  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });

  @override
  void close({bool force = false}) {}
}
