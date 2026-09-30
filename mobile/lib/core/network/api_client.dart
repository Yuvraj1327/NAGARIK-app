import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/core/config/env.dart';
import 'package:nagarik/core/network/api_exception.dart';

/// Thin wrapper around [Dio] configured to talk to the FastAPI backend.
///
/// Every request automatically carries the current Supabase session's
/// access token as a Bearer token (once a session exists — Step 3 wires up
/// sign-in, this client just reads whatever session is active). This is the
/// core of the "Flutter -> FastAPI -> Supabase" auth flow described in
/// docs/ARCHITECTURE.md: Flutter never talks to Postgres/Storage directly,
/// it authenticates with Supabase and then calls FastAPI with that token.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = Env.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
          handler.next(_normalize(error));
        },
      ),
    );
  }

  final Dio _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
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
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
