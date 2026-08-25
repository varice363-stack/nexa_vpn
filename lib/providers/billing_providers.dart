import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_transaction.dart';
import '../models/trial_status.dart';
import '../models/premium_plan.dart';
import '../models/subscription_plan.dart';
import '../services/api/api_exception.dart';
import '../services/billing/billing_config.dart';
import 'access_providers.dart';
import 'app_providers.dart';
import 'subscription_providers.dart';

/// Включены ли продажи внутри приложения.
///
/// Значение берётся из флага сборки `PAYMENTS_ENABLED` (см.
/// [BillingConfig]). Отдельный провайдер нужен, чтобы тесты могли
/// проверить оба состояния экрана — с оплатой и без неё, — не собирая
/// приложение заново.
final paymentsEnabledProvider = Provider<bool>(
  (ref) => BillingConfig.paymentsEnabled,
);

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

  /// Запасной каталог, пока API недоступен.
  ///
  /// Сроки берутся из id тарифа, а не из отдельного списка: раньше здесь
  /// стоял массив [30, 365, 36500], и добавление квартального тарифа
  /// молча сдвинуло бы сроки у всех остальных.
  static List<SubscriptionPlan> _staticPlans() {
    const local = PremiumPlan.available;
    const daysById = {'monthly': 30, 'quarterly': 90, 'yearly': 365};

    return [
      for (final plan in local)
        SubscriptionPlan(
          id: 'local-${plan.id}',
          code: plan.id.toUpperCase(),
          name: 'Nexa ${plan.name}',
          durationDays: daysById[plan.id] ?? 30,
          // Из «199 ₽» достаём число, символ валюты отбрасываем.
          price:
              double.tryParse(plan.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
                  0,
          currency: BillingConfig.defaultCurrency,
          description: plan.description,
        ),
    ];
  }
}

/// Payment history of the current user (`GET /billing/transactions`).
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<PaymentTransaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<PaymentTransaction>> {
  @override
  Future<List<PaymentTransaction>> build() async {
    try {
      return await ref.watch(billingRepositoryProvider).getTransactions();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Transactions unavailable: $e', source: 'api');
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
        await ref.read(billingRepositoryProvider).getTransactions(),
      );
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Transactions refresh failed: $e', source: 'api');
      state = const AsyncData([]);
    }
  }
}

/// Trial availability (`GET /billing/trial/status`).
final trialStatusProvider =
    AsyncNotifierProvider<TrialStatusNotifier, TrialStatus>(
  TrialStatusNotifier.new,
);

class TrialStatusNotifier extends AsyncNotifier<TrialStatus> {
  @override
  Future<TrialStatus> build() async {
    try {
      return await ref.watch(billingRepositoryProvider).getTrialStatus();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Trial status unavailable: $e', source: 'api');
      return const TrialStatus(available: false, used: false);
    }
  }

  Future<bool> activate() async {
    try {
      await ref.read(billingRepositoryProvider).activateTrial();
      state = const AsyncData(TrialStatus(available: false, used: true));
      // Refresh dependent state: subscription + access keys.
      await ref.read(subscriptionProvider.notifier).refresh();
      await ref.read(accessKeysProvider.notifier).refresh();
      return true;
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Trial activation failed: $e', source: 'api');
      return false;
    }
  }
}
