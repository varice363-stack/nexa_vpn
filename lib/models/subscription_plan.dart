/// Форматирует сумму в валюте тарифа: «199 ₽», «1490 ₽», «$11.99».
///
/// Дробная часть отбрасывается, когда она нулевая: «199 ₽» вместо
/// «199.00 ₽» — так цена читается с одного взгляда.
String formatMoney(double amount, String currency) {
  final whole = amount == amount.roundToDouble();
  final text = whole ? amount.round().toString() : amount.toStringAsFixed(2);
  switch (currency.toUpperCase()) {
    case 'RUB':
      return '$text \u20BD';
    case 'USD':
      return '\u0024$text';
    case 'EUR':
      return '\u20AC$text';
    default:
      return '$currency $text';
  }
}

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

  String get priceLabel => formatMoney(price, currency);

  /// Цена за месяц для длинных тарифов, округлённая до рубля.
  ///
  /// Нужна, чтобы годовой тариф читался выгодным рядом с месячным.
  /// Для месячного тарифа возвращает null: дублировать цену незачем.
  /// Слово «в месяц» подставляет UI из переводов — модель не знает языка.
  int? get monthlyEquivalent {
    if (durationDays < 60) return null;
    final months = durationDays / 30.0;
    if (months < 1.5) return null;
    return (price / months).round();
  }

  /// Экономия относительно месячного тарифа, в валюте тарифа.
  ///
  /// Возвращает null, если экономии нет или тариф сам месячный.
  int? savingsAgainst(SubscriptionPlan monthly) {
    if (durationDays < 60 || monthly.durationDays <= 0) return null;
    final months = durationDays / monthly.durationDays;
    final full = monthly.price * months;
    final diff = (full - price).round();
    return diff > 0 ? diff : null;
  }

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
      currency: json['currency'] as String? ?? 'RUB',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
