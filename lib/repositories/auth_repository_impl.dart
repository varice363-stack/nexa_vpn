import '../domain/repositories/auth_repository.dart';
import '../models/auth_user.dart';
import '../services/api/api_client.dart';

/// [AuthRepository] backed by the Nexa VPN API.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<AuthResult> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthResult.fromJson(_asMap(data));
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    String? country,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        if (country != null && country.isNotEmpty) 'country': country,
      },
    );
    return AuthResult.fromJson(_asMap(data));
  }

  @override
  Future<AuthResult> autoRegister({
    required String deviceId,
    String? country,
    String? platform,
    String? modelName,
  }) async {
    final data = await _api.post(
      '/auth/auto-register',
      body: {
        'deviceId': deviceId,
        if (country != null && country.isNotEmpty) 'country': country,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
        if (modelName != null && modelName.isNotEmpty) 'modelName': modelName,
      },
    );
    return AuthResult.fromJson(_asMap(data));
  }

  @override
  Future<AuthUser> me() async {
    final data = await _api.get('/auth/me');
    return AuthUser.fromJson(_asMap(data));
  }

  @override
  Future<void> logout() async {
    // Token is cleared by the auth provider; nothing to do server-side.
  }

  Map<String, Object?> _asMap(dynamic data) {
    if (data is! Map) {
      throw const FormatException('Unexpected response shape');
    }
    return Map<String, Object?>.from(data);
  }
}
