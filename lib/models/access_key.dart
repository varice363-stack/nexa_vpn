/// Access key — the platform's core product (mirror of the backend
/// AccessKey contract). The key grants access and can be used by the
/// Nexa app or any compatible VLESS client.
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
    this.server,
    this.configUri,
    this.qrPayload,
    this.code,
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

  /// Ingress server summary (present for ACTIVE keys with a config).
  final AccessServer? server;

  /// Full `vless://...` configuration — ACTIVE keys only.
  final String? configUri;

  /// QR payload (equals configUri; client renders the QR).
  final String? qrPayload;

  /// Redemption code (NEXA-XXXX-XXXX) for standalone keys sold to customers.
  /// Only returned to the issuing admin and to the redeemer.
  final String? code;

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isRevoked => status == 'REVOKED';

  bool get hasConfig => configUri != null && configUri!.isNotEmpty;

  /// Days left until expiry (null = never expires / lifetime).
  int? get daysLeft {
    final expires = expiresAt;
    if (expires == null) return null;
    return expires.difference(DateTime.now()).inDays;
  }

  factory AccessKey.fromJson(Map<String, Object?> json) {
    DateTime? parse(String? raw) =>
        raw == null ? null : DateTime.tryParse(raw);

    final serverJson = json['server'] as Map<String, Object?>?;
    final config = json['config'] as Map<String, Object?>?;

    return AccessKey(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Access Key',
      status: json['status'] as String? ?? 'ACTIVE',
      protocol: json['protocol'] as String? ?? 'VLESS',
      createdAt: parse(json['createdAt'] as String?),
      expiresAt: parse(json['expiresAt'] as String?),
      lastUsedAt: parse(json['lastUsedAt'] as String?),
      code: json['code'] as String?,
      deviceId: json['deviceId'] as String?,
      deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 0,
      server: serverJson == null
          ? null
          : AccessServer(
              id: serverJson['id'] as String,
              name: serverJson['name'] as String? ?? '',
              country: serverJson['country'] as String? ?? '',
              countryCode: serverJson['countryCode'] as String? ?? '',
              city: serverJson['city'] as String? ?? '',
              ip: serverJson['ip'] as String? ?? '',
            ),
      configUri: config?['uri'] as String?,
      qrPayload: config?['qrPayload'] as String?,
    );
  }
}

/// Minimal ingress server summary attached to a key config.
class AccessServer {
  const AccessServer({
    required this.id,
    required this.name,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.ip,
  });

  final String id;
  final String name;
  final String country;
  final String countryCode;
  final String city;
  final String ip;

  String get flagEmoji {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌐';
    final buffer = StringBuffer();
    for (final unit in code.codeUnits) {
      if (unit < 0x41 || unit > 0x5A) return '🌐';
      buffer.writeCharCode(0x1F1E6 + (unit - 0x41));
    }
    return buffer.toString();
  }

  String get location => '$city, $country';
}
