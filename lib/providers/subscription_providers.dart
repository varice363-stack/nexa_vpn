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

  /// Simulated purchase.
  ///
  /// BILLING INTEGRATION (TODO — external infrastructure):
  /// replace with `in_app_purchase` / RevenueCat once the backend exposes
  /// a purchase/verify endpoint. Today the state is persisted locally.
  Future<void> subscribe(PremiumPlan plan) async {
    final next = SubscriptionState(
      tier: SubscriptionTier.premium,
      planId: plan.id,
      expiresAt: plan.isLifetime
          ? null
          : DateTime.now().add(const Duration(days: 30)),
    );
    state = AsyncData(next);
    await ref.read(configRepositoryProvider).saveSubscription(next);
    ref.read(notificationServiceProvider).push(
          title: 'Welcome to Premium',
          body: '${plan.name} plan is now active. Enjoy unlimited access.',
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
