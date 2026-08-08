/// Result of initiating a checkout (mock today).
class CheckoutResult {
  const CheckoutResult({
    required this.transactionId,
    required this.status,
    this.checkoutUrl,
  });

  final String transactionId;
  final String status;
  final String? checkoutUrl;

  factory CheckoutResult.fromJson(Map<String, Object?> json) {
    return CheckoutResult(
      transactionId: json['transactionId'] as String,
      status: json['status'] as String? ?? 'PENDING',
      checkoutUrl: json['checkoutUrl'] as String?,
    );
  }
}
