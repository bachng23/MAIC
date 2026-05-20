import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the current user's access token to every API request,
/// and clears the token + triggers logout when the server returns 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, {this.onUnauthorized});

  final TokenStorage _tokenStorage;

  /// Called when a 401 is received — use this to trigger app-level logout.
  final void Function()? onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenStorage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _tokenStorage.clearToken();
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
