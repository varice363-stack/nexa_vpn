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

  static const List<PremiumPlan> available = [
    PremiumPlan(
      id: 'monthly',
      name: 'Monthly',
      price: r'$11.99',
      periodLabel: '/ month',
      description: 'Flexible plan, cancel anytime',
      features: [
        'Unlimited data',
        'No-logs policy',
        '5 devices',
        '4K streaming',
        '24/7 support',
      ],
    ),
    PremiumPlan(
      id: 'yearly',
      name: 'Yearly',
      price: r'$5.99',
      periodLabel: '/ month',
      description: 'Billed \$71.88 per year — save 50%',
      features: [
        'Everything in Monthly',
        '10 devices',
        'Priority support',
        'Secure core servers',
        '30-day money back',
      ],
      isPopular: true,
    ),
    PremiumPlan(
      id: 'lifetime',
      name: 'Lifetime',
      price: r'$149',
      periodLabel: ' one-time',
      description: 'Pay once, protect forever',
      features: [
        'Everything in Yearly',
        'Unlimited devices',
        'Early feature access',
        'Lifetime updates',
      ],
      isLifetime: true,
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
