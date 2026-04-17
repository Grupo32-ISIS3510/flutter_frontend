import 'dart:async';

import 'package:flutter/material.dart';
// Almacenamiento cifrado: usa Keystore (Android) / Keychain (iOS) para guardar
// el token de forma segura. NUNCA usar SharedPreferences para tokens.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/features/auth/models/user.dart';
import 'package:second_serving_frontend/features/auth/services/auth_service.dart';

// Modelar el estado como enum evita estados imposibles (e.g. loading + authenticated
// a la vez). Principio: "make illegal states unrepresentable".
enum AuthState { initial, loading, authenticated, unauthenticated, error }

// ChangeNotifier = implementación de Flutter del patrón Observer. Mantiene una
// lista interna de listeners y notifyListeners() los invoca para recomponer la UI.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;          // Capa de red (abstracción → testeable)
  final ApiClient _apiClient;              // Cliente HTTP compartido (para inyectar token)
  final Future<void> Function()? _onAuthenticated; // Hook opcional post-login (ej. precargar datos)
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Estado privado: solo el provider lo muta. La UI lo lee por getters.
  AuthState _state = AuthState.initial;
  User? _user;
  String? _token;
  String? _error;

  AuthProvider(this._authService, this._apiClient, {Future<void> Function()? onAuthenticated})
      : _onAuthenticated = onAuthenticated;

  // Getters públicos = API de lectura para la UI. Encapsulamiento.
  AuthState get state => _state;
  User? get user => _user;
  String? get token => _token;
  String? get error => _error;
  // Helpers booleanos para evitar comparaciones de enum repartidas por la UI.
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  // Rehidratación de sesión al iniciar la app (llamado desde SplashScreen).
  Future<void> checkAuth() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      // Lectura asíncrona del Keystore (operación I/O via platform channel).
      _token = await _storage.read(key: 'auth_token');
      if (_token != null) {
        // Inyecta el token en el cliente HTTP para que las próximas requests
        // incluyan automáticamente el header Authorization: Bearer ...
        _apiClient.setToken(_token);
        // Validar contra backend: tener token NO basta, puede estar expirado.
        _user = await _authService.getMe();
        _state = AuthState.authenticated;
        // unawaited() = "sé que esto retorna Future pero intencionalmente no lo
        // espero" (silencia el linter discarded_futures sin bloquear la UI).
        unawaited(_notifyAuthenticated());
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      // Si /auth/me falla (token inválido/expirado), limpiar todo el estado
      // de auth para forzar al usuario a hacer login otra vez.
      _token = null;
      _apiClient.setToken(null);
      await _storage.delete(key: 'auth_token');
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // Devuelve bool en vez de exponer _state directamente → menor acoplamiento:
  // la UI solo necesita saber "¿navegamos a /home o no?".
  Future<bool> login({required String email, required String password}) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();          // ① Disparo 1: la UI muestra spinner

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      _token = response.accessToken;
      _user = response.user;
      // Persistir cifrado para que el usuario no tenga que loguearse cada vez.
      await _storage.write(key: 'auth_token', value: _token);
      _state = AuthState.authenticated;
      unawaited(_notifyAuthenticated());
      notifyListeners();        // ② Disparo 2: la UI navega a /home
      return true;
    } catch (e) {
      // Cualquier error (red, credenciales, timeout) llega aquí.
      // ApiException.toString() devuelve el mensaje legible para el usuario.
      _error = e.toString();
      _state = AuthState.error;
      notifyListeners();        // ③ Disparo 3: la UI muestra el mensaje de error
      return false;
    }
  }

  // Mismo patrón que login: setear loading → llamar service → manejar éxito/error.
  // La duplicación es intencional para mantener legibilidad en cada flujo.
  Future<bool> register({
    required String email,
    required String fullName,
    required String password,
    String? location,           // Opcional: solo se envía si tiene valor
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
      // Notifica al backend (revoca el token server-side si aplica). Si falla
      // la red, igual continuamos con el logout local: la UX local manda.
      await _authService.logout();
    } catch (_) {}
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');   // Borrar token cifrado del device
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // La UI llama esto cuando el usuario tapea la X del banner de error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Hook opcional que main.dart usa para precargar datos (e.g. dashboard) tras login.
  // Se ejecuta sin bloquear: si falla, el login sigue siendo exitoso.
  Future<void> _notifyAuthenticated() async {
    if (_onAuthenticated == null) {
      return;
    }

    try {
      await _onAuthenticated();
    } catch (_) {}
  }
}
