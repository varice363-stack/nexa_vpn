/// Subscription plan (mirror of the backend SubscriptionPlan).
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.durationDays,
    required this.price,
    required this.currency,
    this.description,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final int durationDays;
  final double price;
  final String currency;
  final String? description;
  final bool isActive;

  String get priceLabel => '$currency ${price.toStringAsFixed(2)}';

  String get durationLabel => durationDays >= 365
      ? '1 year'
      : durationDays >= 90
          ? '${(durationDays / 30).round()} months'
          : '$durationDays days';

  factory SubscriptionPlan.fromJson(Map<String, Object?> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      code: json['code'] as String? ?? 'MONTHLY',
      name: json['name'] as String,
      durationDays: (json['durationDays'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
