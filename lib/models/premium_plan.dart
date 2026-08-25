/// Subscription tiers.
enum SubscriptionTier { free, premium }

/// A purchasable subscription plan (presentation model).
class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.periodLabel,
    required this.description,
    required this.features,
    this.isPopular = false,
    this.isLifetime = false,
  });

  final String id;
  final String name;
  final String price;
  final String periodLabel;
  final String description;
  final List<String> features;
  final bool isPopular;
  final bool isLifetime;

  /// Запасной каталог: показывается, пока приложение не достучалось
  /// до сервера. Цены обязаны совпадать с боевыми (backend/prisma/seed.ts),
  /// иначе человек увидит одну сумму, а заплатит другую.
  ///
  /// Пожизненный тариф снят с продажи: при аренде сервера ~500 ₽/мес он
  /// со временем работает в минус.
  static const List<PremiumPlan> available = [
    PremiumPlan(
      id: 'monthly',
      name: '30 дней',
      price: '199 \u20BD',
      periodLabel: '/ мес',
      description: 'Помесячно, без автопродления',
      features: [
        'Безлимитный трафик',
        'Логи подключений не ведутся',
        'Свои ключи и ключи других провайдеров',
        'Поддержка в Telegram',
      ],
    ),
    PremiumPlan(
      id: 'quarterly',
      name: '90 дней',
      price: '499 \u20BD',
      periodLabel: '/ 3 мес',
      description: 'Выгоднее на 98 \u20BD',
      features: [
        'Всё из тарифа на 30 дней',
        '\u2248166 \u20BD в месяц',
      ],
    ),
    PremiumPlan(
      id: 'yearly',
      name: '365 дней',
      price: '1490 \u20BD',
      periodLabel: '/ год',
      description: 'Выгоднее на 898 \u20BD',
      features: [
        'Всё из тарифа на 90 дней',
        '\u2248124 \u20BD в месяц',
        'Приоритетная поддержка',
      ],
      isPopular: true,
    ),
  ];
}

/// Current subscription state.
class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.planId,
    this.expiresAt,
  });

  final SubscriptionTier tier;
  final String? planId;
  final DateTime? expiresAt;

  bool get isPremium => tier == SubscriptionTier.premium;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    String? planId,
    DateTime? expiresAt,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      planId: planId ?? this.planId,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
