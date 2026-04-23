import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/features/auth/models/user.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

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

class AuthServiceImpl implements AuthService {
  final ApiClient _client;

  AuthServiceImpl(this._client);

  @override
  Future<AuthResponse> register({
    required String email,
    required String fullName,
    required String password,
    String? location,
  }) async {
    final response = await _client.post(ApiConfig.register, body: {
      'email': email,
      'full_name': fullName,
      'password': password,
      if (location != null) 'location': location,
    });
    final authResponse = AuthResponse.fromJson(response);
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
    _client.setToken(authResponse.accessToken);
    return authResponse;
  }

  @override
  Future<void> logout() async {
    await _client.post(ApiConfig.logout);
    _client.setToken(null);
  }

  @override
  Future<User> getMe() async {
    final response = await _client.get(ApiConfig.me);
    return User.fromJson(response);
  }
}
