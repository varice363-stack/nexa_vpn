/// Уровень подписки, как его видит приложение.
///
/// `free` — подписки нет; `standard` и `premium` — платная подписка. Лимитов
/// устройств приложение сейчас не применяет (см. экран «Устройства»).
enum SubscriptionTier {
  free,
  standard,
  premium,
}

/// Текущее состояние подписки. Источник правды — бэкенд (GET /subscriptions/me).
class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.planId,
    this.expiresAt,
    this.isTrialActive = false,
  });

  final SubscriptionTier tier;
  final String? planId;
  final DateTime? expiresAt;
  final bool isTrialActive;

  bool get isPremium =>
      tier == SubscriptionTier.standard || tier == SubscriptionTier.premium;

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
    bool? isTrialActive,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      planId: planId ?? this.planId,
      expiresAt: expiresAt ?? this.expiresAt,
      isTrialActive: isTrialActive ?? this.isTrialActive,
    );
  }
}
