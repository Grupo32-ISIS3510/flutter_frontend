import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/features/auth/models/user.dart';
import 'package:second_serving_frontend/features/auth/services/auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final AuthService _authService;
  final ApiClient _apiClient;
  final Future<void> Function()? _onAuthenticated;
  final Future<void> Function()? _onLogout;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthState _state = AuthState.initial;
  User? _user;
  String? _token;
  String? _error;

  AuthProvider(
    this._authService,
    this._apiClient, {
    Future<void> Function()? onAuthenticated,
    Future<void> Function()? onLogout,
  })  : _onAuthenticated = onAuthenticated,
        _onLogout = onLogout;

  AuthState get state => _state;
  User? get user => _user;
  String? get token => _token;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  /// Restaura la sesión desde el storage. Tolera fallos de red:
  /// - Si hay token y user cacheados → autentica de inmediato (UI usable),
  ///   y refresca [User] en background.
  /// - Solo desloguea ante 401 explícito (token revocado).
  /// - Si nunca se ha visto al user antes y getMe falla por red → unauthenticated.
  Future<void> checkAuth() async {
    _state = AuthState.loading;
    notifyListeners();

    // Cache en memoria evita relectura de Keystore/Keychain en hot paths.
    _token ??= await _storage.read(key: _tokenKey);
    _user ??= await _readPersistedUser();

    if (_token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    _apiClient.setToken(_token);

    if (_user != null) {
      // Optimistic: la UI ya puede entrar al home. Refrescamos en background.
      _state = AuthState.authenticated;
      notifyListeners();
      unawaited(_refreshUserInBackground());
      unawaited(_notifyAuthenticated());
      return;
    }

    // No hay user cacheado: necesitamos verificar contra el backend.
    try {
      _user = await _authService.getMe();
      await _persistUser(_user!);
      _state = AuthState.authenticated;
      unawaited(_notifyAuthenticated());
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _hardLogout();
      } else {
        // Error del backend distinto a 401: no podemos confirmar la sesión,
        // pero tampoco podemos confiar en ella sin haber visto al user.
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      // Red caída sin user cacheado: no entramos.
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> _refreshUserInBackground() async {
    try {
      final fresh = await _authService.getMe();
      _user = fresh;
      await _persistUser(fresh);
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Token revocado mientras estábamos offline → logout silencioso.
        await _hardLogout();
        notifyListeners();
      }
      // Otros errores HTTP: ignoramos, dejamos al user cacheado.
    } catch (_) {
      // Error de red: mantenemos sesión cacheada.
    }
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
      await _storage.write(key: _tokenKey, value: _token);
      await _persistUser(_user!);
      _state = AuthState.authenticated;
      unawaited(_notifyAuthenticated());
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
      await _storage.write(key: _tokenKey, value: _token);
      await _persistUser(_user!);
      _state = AuthState.authenticated;
      unawaited(_notifyAuthenticated());
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
    await _hardLogout();
    notifyListeners();
  }

  Future<void> _hardLogout() async {
    _token = null;
    _user = null;
    _apiClient.setToken(null);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _state = AuthState.unauthenticated;
    if (_onLogout != null) {
      try {
        await _onLogout();
      } catch (e) {
        debugPrint('[AuthProvider] onLogout callback failed: $e');
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _notifyAuthenticated() async {
    if (_onAuthenticated == null) {
      return;
    }

    try {
      await _onAuthenticated();
    } catch (_) {}
  }

  Future<void> _persistUser(User user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('[AuthProvider] persistUser failed: $e');
    }
  }

  Future<User?> _readPersistedUser() async {
    try {
      final raw = await _storage.read(key: _userKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(json);
    } catch (e) {
      debugPrint('[AuthProvider] readPersistedUser failed (cache corrupta?): $e');
      return null;
    }
  }
}
