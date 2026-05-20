import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the Bearer token to every request.
/// On 401, tries to refresh the access token once using the refresh token.
/// If refresh also fails, calls [onUnauthorized] to trigger app-level logout.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._tokenStorage, {
    this.onRefreshToken,
    this.onUnauthorized,
  });

  final TokenStorage _tokenStorage;

  /// Called to perform the token refresh. Returns the new access token,
  /// or null/throws if refresh fails.
  final Future<String?> Function()? onRefreshToken;

  /// Called when a 401 occurs and refresh is not possible or also fails.
  final void Function()? onUnauthorized;

  bool _isRefreshing = false;

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
    if (err.response?.statusCode == 401 && !_isRefreshing && onRefreshToken != null) {
      _isRefreshing = true;
      try {
        final newToken = await onRefreshToken!();
        if (newToken != null) {
          // Retry the original request with the new token
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          // Use a bare Dio to avoid going through this interceptor again
          final retryDio = Dio(
            BaseOptions(
              baseUrl: opts.baseUrl,
              connectTimeout: opts.connectTimeout,
              receiveTimeout: opts.receiveTimeout,
            ),
          );
          final response = await retryDio.fetch(opts);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // Refresh failed — fall through to logout
      } finally {
        _isRefreshing = false;
      }

      // Refresh failed: clear tokens and logout
      await _tokenStorage.clearAll();
      onUnauthorized?.call();
    } else if (err.response?.statusCode == 401) {
      await _tokenStorage.clearAll();
      onUnauthorized?.call();
    }

    handler.next(err);
  }
}
