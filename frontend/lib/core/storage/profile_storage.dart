import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/profile/domain/user_profile_info.dart';

class ProfileStorage {
  ProfileStorage(this._storage);

  final FlutterSecureStorage _storage;

  String _keyForUser(String userId) => 'maic_user_profile_$userId';

  Future<UserProfileInfo?> read(String userId) async {
    final raw = await _storage.read(key: _keyForUser(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfileInfo.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, UserProfileInfo profile) {
    return _storage.write(
      key: _keyForUser(userId),
      value: jsonEncode(profile.toJson()),
    );
  }

  Future<void> clear(String userId) {
    return _storage.delete(key: _keyForUser(userId));
  }
}
