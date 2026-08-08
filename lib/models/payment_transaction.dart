/// Payment transaction (mirror of the backend PaymentTransaction).
class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.provider,
    this.createdAt,
  });

  final String id;

  /// PENDING | PAID | FAILED | REFUNDED | CANCELLED.
  final String status;
  final double amount;
  final String currency;
  final String provider;
  final DateTime? createdAt;

  factory PaymentTransaction.fromJson(Map<String, Object?> json) {
    final createdAt = json['createdAt'] as String?;
    return PaymentTransaction(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      provider: json['provider'] as String? ?? 'INTERNAL',
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
    );
  }
}
