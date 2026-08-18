import 'payment_status.dart';
/// Payment transaction (mirror of the backend PaymentTransaction).
class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.provider,
    this.planName,
    this.createdAt,
  });

  final String id;

  /// PENDING | PAID | FAILED | REFUNDED | CANCELLED.
  final String status;
  final double amount;
  final String currency;
  final String provider;
  final String? planName;
  final DateTime? createdAt;

  /// Convenience: parsed UI status.
  PaymentStatus get uiStatus => PaymentStatus.fromBackend(status);

  factory PaymentTransaction.fromJson(Map<String, Object?> json) {
    final createdAt = json['createdAt'] as String?;
    return PaymentTransaction(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      provider: json['provider'] as String? ?? 'INTERNAL',
      planName: json['planName'] as String?,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
    );
  }
}
