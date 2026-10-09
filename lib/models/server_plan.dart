/// Тариф, который реально продаётся: цена и срок приходят с сервера
/// (`GET /plans`), а не зашиты в приложение.
///
/// Почему это отдельная модель вместо статичного списка тарифов в коде:
/// зашитые в код цены разъехались с базой (в приложении 299 ₽, в базе 199 ₽),
/// и человек видел одну цену, а платил другую. Экран тарифов обязан
/// показывать серверные данные.
class ServerPlan {
  const ServerPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.durationDays,
    required this.price,
    this.description,
    this.currency = 'RUB',
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final int durationDays;
  final int price;
  final String currency;
  final bool isActive;

  /// «199 ₽» — цена как её видит покупатель.
  String get priceLabel => '$price ₽';

  /// «30 дней» / «365 дней».
  String get daysLabel {
    final n = durationDays;
    final tail = n % 10 == 1 && n % 100 != 11
        ? 'день'
        : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20))
            ? 'дня'
            : 'дней';
    return '$n $tail';
  }

  /// Цена за месяц — чтобы было видно, какой тариф выгоднее.
  String get perMonthLabel {
    if (durationDays <= 0) return '';
    final months = durationDays / 30.0;
    if (months < 1.5) return '';
    return '≈${(price / months).round()} ₽/мес';
  }

  factory ServerPlan.fromJson(Map<String, Object?> json) {
    return ServerPlan(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'Тариф',
      description: json['description'] as String?,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      price: (json['price'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'RUB',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
