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

  /// POST /auth/auto-register — device-only login, no email/password.
  /// Creates an anonymous account on first call, refreshes the token on
  /// subsequent calls. The server-side [deviceId] is matched against
  /// the user table, so a lost token on the client simply re-authenticates.
  Future<AuthResult> autoRegister({
    required String deviceId,
    String? country,
    String? platform,
    String? modelName,
  });

  /// GET /auth/me — current user. Throws [ApiException] on failure.
  Future<AuthUser> me();

  /// Local-only: clears nothing server-side (token lifecycle is owned by
  /// the auth provider).
  Future<void> logout();
}
