import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/features/auth/models/user.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

// CONTRATO (interfaz): define QUÉ hace el servicio sin decir CÓMO.
// Permite Dependency Inversion → el AuthProvider depende de esta abstracción,
// no de la implementación concreta. En main.dart se inyecta MockAuthService
// (para tests/desarrollo) o AuthServiceImpl (producción) según ApiConfig.useMockAuth.
abstract class AuthService {
  Future<AuthResponse> register({
    required String email,
    required String fullName,
    required String password,
    String? location,
  });

  Future<AuthResponse> login({
    required String email,
    required String password,
  });

  Future<void> logout();
  Future<User> getMe();
}

// IMPLEMENTACIÓN REAL: traduce las llamadas del provider a peticiones HTTP.
class AuthServiceImpl implements AuthService {
  final ApiClient _client;        // Cliente HTTP compartido (singleton vía Provider)

  AuthServiceImpl(this._client);

  @override
  Future<AuthResponse> register({
    required String email,
    required String fullName,
    required String password,
    String? location,
  }) async {
    // Endpoint definido en ApiConfig (centralizado para cambiar de ambiente).
    final response = await _client.post(ApiConfig.register, body: {
      'email': email,
      'full_name': fullName,                    // snake_case = convención REST/Python backend
      'password': password,
      // Collection-if: solo agrega la clave 'location' si tiene valor.
      // Evita enviar "location": null al backend (más limpio que ternarios).
      if (location != null) 'location': location,
    });
    // Factory: convierte Map<String, dynamic> en objeto fuertemente tipado.
    final authResponse = AuthResponse.fromJson(response);
    // SIDE EFFECT importante: tras registrar, ya quedamos autenticados,
    // así que inyectamos el token en el cliente para las próximas requests.
    _client.setToken(authResponse.accessToken);
    return authResponse;
  }

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(ApiConfig.login, body: {
      'email': email,
      'password': password,
    });
    final authResponse = AuthResponse.fromJson(response);
    _client.setToken(authResponse.accessToken);   // Mismo patrón que register
    return authResponse;
  }

  @override
  Future<void> logout() async {
    await _client.post(ApiConfig.logout);          // Notifica al backend
    _client.setToken(null);                        // Limpia el token en memoria
  }

  // Endpoint clásico "yo mismo": valida que el token sea válido y devuelve el usuario.
  // Lo usa AuthProvider.checkAuth() al iniciar la app.
  @override
  Future<User> getMe() async {
    final response = await _client.get(ApiConfig.me);
    return User.fromJson(response);
  }
}
