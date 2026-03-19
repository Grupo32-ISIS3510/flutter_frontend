import 'package:second_serving_frontend/models/user.dart';
import 'package:second_serving_frontend/services/auth_service.dart';
import 'package:second_serving_frontend/services/mock/mock_data.dart';

class MockAuthService implements AuthService {
  User? _currentUser;

  @override
  Future<AuthResponse> register({
    required String email,
    required String fullName,
    required String password,
    String? location,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentUser = User(
      id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      fullName: fullName,
      isPremium: false,
      location: location,
      createdAt: DateTime.now(),
    );
    return AuthResponse(
      accessToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      tokenType: 'bearer',
      user: _currentUser!,
    );
  }

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentUser = MockData.user;
    return AuthResponse(
      accessToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      tokenType: 'bearer',
      user: _currentUser!,
    );
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
  }

  @override
  Future<User> getMe() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _currentUser ?? MockData.user;
  }
}
