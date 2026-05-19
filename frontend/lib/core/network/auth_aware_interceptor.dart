import 'package:dio/dio.dart';

/// Injects stored bearer tokens and clears session state on 401 from protected routes.
///
/// Login may legitimately return 401 (invalid credentials); that must not wipe storage.
class AuthAwareInterceptor extends QueuedInterceptor {
  AuthAwareInterceptor({
    required Future<String?> Function() readToken,
    required Future<void> Function() clearToken,
    required void Function() onUnauthorized,
  })  : _readToken = readToken,
        _clearToken = clearToken,
        _onUnauthorized = onUnauthorized;

  final Future<String?> Function() _readToken;
  final Future<void> Function() _clearToken;
  final void Function() _onUnauthorized;

  static bool _isPublicPath(String path) {
    return path == '/health' ||
        path == '/api/v1/auth/login' ||
        path == '/api/v1/auth/register';
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final path = options.uri.path;
    if (_isPublicPath(path)) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }
    final raw = await _readToken();
    final token = raw?.trim();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.uri.path;
    if (status == 401 && !_isPublicPath(path)) {
      await _clearToken();
      _onUnauthorized();
    }
    handler.next(err);
  }
}
