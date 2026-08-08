import '../../models/auth_user.dart';

/// Authentication contract (backend `/auth/*`).
abstract class AuthRepository {
  /// POST /auth/login
  Future<AuthResult> login(String email, String password);

  /// POST /auth/register
  Future<AuthResult> register({
    required String email,
    required String password,
    String? country,
  });

  /// GET /auth/me — current user. Throws [ApiException] on failure.
  Future<AuthUser> me();

  /// Local-only: clears nothing server-side (token lifecycle is owned by
  /// the auth provider).
  Future<void> logout();
}
