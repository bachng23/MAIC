import 'package:flutter/foundation.dart';

import '../../../core/storage/token_storage.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api, this._tokenStorage);

  final MediGuardApiService _api;
  final TokenStorage _tokenStorage;

  bool isLoading = false;
  String? error;
  bool isAuthenticated = false;

  Future<void> bootstrap() async {
    final token = await _tokenStorage.readToken();
    isAuthenticated = token != null && token.isNotEmpty;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.login(UserLogin(email: email, password: password));
      final token = data['access_token'] as String;
      await _api.setToken(token);
      isAuthenticated = true;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _api.register(UserRegister(
        email: email,
        password: password,
        name: name,
        phone: phone,
      ));
      return await login(email, password);
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    isAuthenticated = false;
    notifyListeners();
  }
}
