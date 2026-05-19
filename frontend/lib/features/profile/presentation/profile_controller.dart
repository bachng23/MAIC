import 'package:flutter/foundation.dart';

import '../../../core/auth/jwt_user_id.dart';
import '../../../core/storage/profile_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user_profile_info.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._profileStorage, this._tokenStorage);

  final ProfileStorage _profileStorage;
  final TokenStorage _tokenStorage;

  UserProfileInfo profile = const UserProfileInfo();
  bool isLoading = false;
  String? error;

  Future<void> bootstrap() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _loadForCurrentUser() ?? const UserProfileInfo();
    } catch (e) {
      error = e.toString();
      profile = const UserProfileInfo();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(UserProfileInfo next) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final userId = await _currentUserId();
      if (userId == null) {
        error = 'Please log in to save your profile.';
        return false;
      }
      await _profileStorage.write(userId, next);
      profile = next;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    profile = const UserProfileInfo();
    error = null;
    isLoading = false;
    notifyListeners();
  }

  Future<UserProfileInfo?> _loadForCurrentUser() async {
    final userId = await _currentUserId();
    if (userId == null) return null;
    return _profileStorage.read(userId);
  }

  Future<String?> _currentUserId() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;
    return userIdFromAccessToken(token);
  }
}
