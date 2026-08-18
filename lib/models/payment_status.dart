/// Payment statuses exposed to the UI (checkout/payment flow + history).
enum PaymentStatus {
  pending,
  processing,
  paid,
  failed;

  String get label => switch (this) {
        pending => 'Pending',
        processing => 'Processing',
        paid => 'Paid',
        failed => 'Failed',
      };

  /// Maps a backend transaction status string onto the enum.
  static PaymentStatus fromBackend(String? status) => switch (status) {
        'PAID' => PaymentStatus.paid,
        'FAILED' => PaymentStatus.failed,
        'CANCELLED' || 'REFUNDED' => PaymentStatus.failed,
        _ => PaymentStatus.pending,
      };
}
