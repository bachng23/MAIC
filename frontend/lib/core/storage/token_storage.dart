import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  static const _accessKey = 'maic_access_token';
  static const _refreshKey = 'maic_refresh_token';
  final FlutterSecureStorage _storage;

  // Access token
  Future<String?> readToken() => _storage.read(key: _accessKey);
  Future<void> writeToken(String token) => _storage.write(key: _accessKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _accessKey);

  // Refresh token
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
  Future<void> writeRefreshToken(String token) => _storage.write(key: _refreshKey, value: token);
  Future<void> clearRefreshToken() => _storage.delete(key: _refreshKey);

  // Clear both
  Future<void> clearAll() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
