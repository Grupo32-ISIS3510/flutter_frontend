import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:second_serving_frontend/models/user.dart';
import 'package:second_serving_frontend/services/auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthState _state = AuthState.initial;
  User? _user;
  String? _token;
  String? _error;

  AuthProvider(this._authService);

  AuthState get state => _state;
  User? get user => _user;
  String? get token => _token;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  Future<void> checkAuth() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      _token = await _storage.read(key: 'auth_token');
      if (_token != null) {
        _user = await _authService.getMe();
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      _token = null;
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      _token = response.accessToken;
      _user = response.user;
      await _storage.write(key: 'auth_token', value: _token);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String fullName,
    required String password,
    String? location,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        email: email,
        fullName: fullName,
        password: password,
        location: location,
      );
      _token = response.accessToken;
      _user = response.user;
      await _storage.write(key: 'auth_token', value: _token);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
