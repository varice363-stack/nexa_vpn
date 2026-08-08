/// Access key — the platform's core product (mirror of the backend
/// AccessKey contract). The key grants access and can be used by the
/// Nexa app or any compatible third-party client.
class AccessKey {
  const AccessKey({
    required this.id,
    required this.name,
    required this.status,
    required this.protocol,
    this.createdAt,
    this.expiresAt,
    this.lastUsedAt,
    this.deviceId,
    this.deviceCount = 0,
  });

  final String id;
  final String name;

  /// ACTIVE | REVOKED | EXPIRED.
  final String status;

  /// VLESS | WIREGUARD (reserved).
  final String protocol;

  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final String? deviceId;
  final int deviceCount;

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isRevoked => status == 'REVOKED';

  /// Days left until expiry (null = never expires / lifetime).
  int? get daysLeft {
    final expires = expiresAt;
    if (expires == null) return null;
    return expires.difference(DateTime.now()).inDays;
  }

  factory AccessKey.fromJson(Map<String, Object?> json) {
    DateTime? parse(String? raw) =>
        raw == null ? null : DateTime.tryParse(raw);

    return AccessKey(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Access Key',
      status: json['status'] as String? ?? 'ACTIVE',
      protocol: json['protocol'] as String? ?? 'VLESS',
      createdAt: parse(json['createdAt'] as String?),
      expiresAt: parse(json['expiresAt'] as String?),
      lastUsedAt: parse(json['lastUsedAt'] as String?),
      deviceId: json['deviceId'] as String?,
      deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 0,
    );
  }
}
