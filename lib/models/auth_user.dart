/// Backend user roles (mirror of the backend `Role` enum).
enum UserRole {
  user,
  premium,
  admin;

  static UserRole fromName(String? name) => UserRole.values.firstWhere(
        (role) => role.name == name,
        orElse: () => UserRole.user,
      );
}

/// Authenticated user returned by `/auth/*` (без passwordHash).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.country,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? country;

  bool get isPremium =>
      role == UserRole.premium || role == UserRole.admin;

  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: UserRole.fromName(json['role'] as String?),
      country: json['country'] as String?,
    );
  }
}

/// Result of a successful login / registration.
class AuthResult {
  const AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;

  factory AuthResult.fromJson(Map<String, Object?> json) {
    return AuthResult(
      accessToken: json['accessToken'] as String,
      user: AuthUser.fromJson(
        Map<String, Object?>.from(json['user'] as Map),
      ),
    );
  }
}
