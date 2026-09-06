/// Subscription tiers.
enum SubscriptionTier {
  /// Free tier: 3 ГБ/мес, 1 device, basic servers
  free,

  /// Standard tier: unlimited traffic, 3 devices, all servers
  standard,

  /// Premium tier: unlimited traffic, 5 devices, priority support
  premium,
}

/// Device limits per subscription tier.
///
/// Matches competitive analysis with Red Shield VPN (7 devices).
/// We offer slightly less but with better protocol stack.
const Map<SubscriptionTier, int> tierDeviceLimits = {
  SubscriptionTier.free: 1,
  SubscriptionTier.standard: 3,
  SubscriptionTier.premium: 5,
};

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
    this.isTrial = false,
    this.trialDays = 0,
    this.deviceLimit = 1,
    this.trafficLimitGb,
  });

  final String id;
  final String name;
  final String price;
  final String periodLabel;
  final String description;
  final List<String> features;
  final bool isPopular;
  final bool isLifetime;
  final bool isTrial;
  final int trialDays;
  final int deviceLimit;
  final int? trafficLimitGb;

  /// Каталог тарифов.
  ///
  /// Цены синхронизированы с backend (backend/prisma/seed.ts).
  /// Конкурентный анализ: Red Shield VPN — 299₽/мес, 799₽/3мес, 2399₽/год.
  /// Наше преимущество: VLESS + Reality (95-98% обход ТСПУ).
  static const List<PremiumPlan> available = [
    // Trial — 7 days free (highest conversion, like Official VPN)
    PremiumPlan(
      id: 'trial',
      name: 'Пробный период',
      price: '0 \u20BD',
      periodLabel: '/ 7 дней',
      description: 'Полный доступ без ограничений',
      features: [
        '7 дней бесплатно',
        'Безлимитный трафик',
        '3 устройства',
        'Все серверы',
        'VLESS + Reality + Vision',
        'Без привязки карты',
      ],
      isTrial: true,
      trialDays: 7,
      deviceLimit: 3,
    ),

    // Standard tier — main revenue driver
    PremiumPlan(
      id: 'standard_monthly',
      name: 'Standard',
      price: '299 \u20BD',
      periodLabel: '/ мес',
      description: 'Полный стек антицензуры',
      features: [
        'Безлимитный трафик',
        '3 устройства',
        'Все серверы (10+ стран)',
        'VLESS + Reality + Vision',
        'Auto-reconnect',
        'Kill Switch',
      ],
      deviceLimit: 3,
    ),

    // Premium tier — power users
    PremiumPlan(
      id: 'premium_yearly',
      name: 'Premium',
      price: '4490 \u20BD',
      periodLabel: '/ год',
      description: 'Максимальная защита',
      features: [
        'Всё из Standard',
        '5 устройств',
        'Priority серверы',
        'Early access к фичам',
        'Telegram-бот поддержка',
        '\u2248374 \u20BD в месяц',
      ],
      isPopular: true,
      deviceLimit: 5,
    ),
  ];

  /// Get device limit for a specific tier.
  static int getDeviceLimit(SubscriptionTier tier) {
    return tierDeviceLimits[tier] ?? 1;
  }
}

/// Current subscription state.
class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.planId,
    this.expiresAt,
    this.devicesUsed = 0,
    this.isTrialActive = false,
  });

  final SubscriptionTier tier;
  final String? planId;
  final DateTime? expiresAt;
  final int devicesUsed;
  final bool isTrialActive;

  bool get isPremium =>
      tier == SubscriptionTier.standard || tier == SubscriptionTier.premium;

  int get deviceLimit => PremiumPlan.getDeviceLimit(tier);

  bool get canAddDevice => devicesUsed < deviceLimit;

  /// Check if trial is still active.
  bool get isTrialValid {
    if (!isTrialActive || expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// Days remaining in trial.
  int get trialDaysLeft {
    if (!isTrialValid || expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inDays.clamp(0, 7);
  }

  /// Hours remaining in trial (for more precise countdown).
  int get trialHoursLeft {
    if (!isTrialValid || expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inHours.clamp(0, 168); // 7 days * 24 hours
  }

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    String? planId,
    DateTime? expiresAt,
    int? devicesUsed,
    bool? isTrialActive,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      planId: planId ?? this.planId,
      expiresAt: expiresAt ?? this.expiresAt,
      devicesUsed: devicesUsed ?? this.devicesUsed,
      isTrialActive: isTrialActive ?? this.isTrialActive,
    );
  }
}
