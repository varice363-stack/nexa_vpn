/// Trial availability for the current user (`GET /billing/trial/status`).
class TrialStatus {
  const TrialStatus({
    required this.available,
    required this.used,
    this.expiresAt,
  });

  final bool available;
  final bool used;
  final DateTime? expiresAt;

  factory TrialStatus.fromJson(Map<String, Object?> json) {
    final expiresAt = json['expiresAt'] as String?;
    return TrialStatus(
      available: json['available'] as bool? ?? false,
      used: json['used'] as bool? ?? false,
      expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
    );
  }
}
