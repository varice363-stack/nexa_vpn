import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/premium_plan.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Current subscription state.
///
/// Source of truth: backend `GET /subscriptions/me`. When the API is
/// unreachable, falls back to the local persisted state so the UI keeps
/// working offline.
final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    try {
      return await ref.watch(subscriptionRepositoryProvider).getCurrent();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn(
            'Subscriptions API unavailable ($e) — local fallback',
            source: 'api',
          );
      return ref.watch(configRepositoryProvider).getSubscription();
    }
  }

  /// Activate trial period (7 days free).
  ///
  /// Gives full access to Standard tier features for 7 days.
  /// No payment method required — maximizes conversion.
  Future<void> activateTrial() async {
    final trialPlan = PremiumPlan.available.firstWhere(
      (plan) => plan.isTrial,
      orElse: () => throw Exception('Trial plan not found'),
    );

    final next = SubscriptionState(
      tier: SubscriptionTier.standard,
      planId: trialPlan.id,
      expiresAt: DateTime.now().add(Duration(days: trialPlan.trialDays)),
      isTrialActive: true,
    );

    state = AsyncData(next);
    await ref.read(configRepositoryProvider).saveSubscription(next);

    ref.read(notificationServiceProvider).push(
          title: 'Пробный период активирован',
          body: 'У вас ${trialPlan.trialDays} дней полного доступа без ограничений',
          icon: AppNotificationIcon.promo,
        );
  }

  /// Subscribe to a paid plan.
  ///
  /// BILLING INTEGRATION (TODO — external infrastructure):
  /// replace with `in_app_purchase` / RevenueCat once the backend exposes
  /// a purchase/verify endpoint. Today the state is persisted locally.
  Future<void> subscribe(PremiumPlan plan) async {
    // Determine tier from plan id
    final tier = plan.id.contains('premium')
        ? SubscriptionTier.premium
        : plan.id.contains('standard')
            ? SubscriptionTier.standard
            : SubscriptionTier.free;

    final next = SubscriptionState(
      tier: tier,
      planId: plan.id,
      expiresAt: plan.isLifetime
          ? null
          : DateTime.now().add(const Duration(days: 30)),
      isTrialActive: false, // Paid subscription replaces trial
    );

    state = AsyncData(next);
    await ref.read(configRepositoryProvider).saveSubscription(next);

    ref.read(notificationServiceProvider).push(
          title: tier == SubscriptionTier.free
              ? 'Free plan activated'
              : 'Welcome to ${tier.name}',
          body: tier == SubscriptionTier.free
              ? 'You have 3 GB of free traffic per month.'
              : '${plan.name} plan is now active. Enjoy unlimited access.',
          icon: AppNotificationIcon.promo,
        );
  }

  /// Re-reads the truth from the backend.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
        await ref.read(subscriptionRepositoryProvider).getCurrent(),
      );
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Subscription refresh failed: $e',
          source: 'api');
      state = AsyncData(
        await ref.read(configRepositoryProvider).getSubscription(),
      );
    }
  }

  Future<void> restorePurchases() async {
    // Real restore requires a store backend; re-reading server state is
    // the best available approximation.
    await refresh();
  }

  Future<void> cancel() async {
    const free = SubscriptionState(tier: SubscriptionTier.free);
    state = const AsyncData(free);
    await ref.read(configRepositoryProvider).saveSubscription(free);
  }
}
