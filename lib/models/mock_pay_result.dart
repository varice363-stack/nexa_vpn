/// Result of confirming a mock payment (`POST /billing/mock-pay/:id`).
class MockPayResult {
  const MockPayResult({
    required this.status,
    required this.subscription,
    required this.accessKey,
    this.subscriptionId,
  });

  /// PAID | already_paid | FAILED.
  final String status;

  /// ACTIVE | NONE.
  final String subscription;

  /// ACTIVE | NONE.
  final String accessKey;

  final String? subscriptionId;

  bool get isPaid => status == 'PAID' || status == 'already_paid';

  factory MockPayResult.fromJson(Map<String, Object?> json) {
    return MockPayResult(
      status: json['status'] as String? ?? 'FAILED',
      subscription: json['subscription'] as String? ?? 'NONE',
      accessKey: json['accessKey'] as String? ?? 'NONE',
      subscriptionId: json['subscriptionId'] as String?,
    );
  }
}
