import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/premium_plan.dart';
import '../models/subscription_plan.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Active subscription plans from the backend (`GET /plans`).
///
/// On API failure (offline) falls back to the static catalog so the
/// Premium screen still shows plans with a retry affordance.
final plansProvider =
    AsyncNotifierProvider<PlansNotifier, List<SubscriptionPlan>>(
  PlansNotifier.new,
);

class PlansNotifier extends AsyncNotifier<List<SubscriptionPlan>> {
  @override
  Future<List<SubscriptionPlan>> build() async {
    try {
      return await ref.watch(billingRepositoryProvider).getPlans();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Plans unavailable ($e) — static fallback',
          source: 'api');
      return _staticPlans();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await ref.read(billingRepositoryProvider).getPlans());
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Plans refresh failed: $e', source: 'api');
      state = AsyncData(_staticPlans());
    }
  }

  /// Offline fallback — mirrors the local catalog until the API is reachable.
  static List<SubscriptionPlan> _staticPlans() {
    const local = PremiumPlan.available;
    const days = [30, 365, 36500];
    return [
      for (var i = 0; i < local.length; i++)
        SubscriptionPlan(
          id: 'local-${local[i].id}',
          code: local[i].id.toUpperCase(),
          name: 'Nexa ${local[i].name}',
          durationDays: days[i],
          price: double.tryParse(local[i].price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
          currency: 'USD',
          description: local[i].description,
        ),
    ];
  }
}
