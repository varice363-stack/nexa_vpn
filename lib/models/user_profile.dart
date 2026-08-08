/// Lightweight user identity used by the Profile screen.
class UserProfile {
  const UserProfile({
    this.name = 'Guest',
    this.email = '',
    this.avatarSeed = 0,
  });

  final String name;
  final String email;
  final int avatarSeed;

  bool get hasIdentity => name.isNotEmpty && name != 'Guest';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'N';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserProfile copyWith({String? name, String? email, int? avatarSeed}) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      name: json['name'] as String? ?? 'Guest',
      email: json['email'] as String? ?? '',
      avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {'name': name, 'email': email, 'avatarSeed': avatarSeed};
  }
}
