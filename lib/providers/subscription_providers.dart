import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_key.dart';
import '../models/app_notification.dart';
import '../models/connection_source.dart';
import '../models/premium_plan.dart';
import '../services/api/api_exception.dart';
import '../services/identity/device_fingerprint.dart';
import 'access_providers.dart';
import 'app_providers.dart';
import 'connection_source_providers.dart';
import 'identity_providers.dart';

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

  /// Активирует пробный период **на сервере**.
  ///
  /// Раньше метод лишь записывал «пробный активен» в память телефона: ни
  /// ключа, ни подписки на сервере не появлялось, поэтому после нажатия
  /// кнопки ничего не происходило — подключиться было нечем. Теперь:
  ///
  ///  1. `POST /billing/trial/activate` создаёт TRIAL-подписку и настоящий
  ///     ACTIVE-ключ (3 дня, лимит 2 ГБ) и сразу выкладывает его ядру;
  ///  2. список ключей перечитывается, а выданный ключ становится активным
  ///     источником — то есть кнопка подключения сразу поднимает туннель.
  ///
  /// Ошибка сервера НЕ превращается в «успех»: если связи нет или пробный
  /// уже использован, пользователь видит сообщение, а не зелёную галочку.
  Future<void> activateTrial() async {
    late final SubscriptionState next;
    try {
      next = await ref.read(subscriptionRepositoryProvider).activateTrial();
    } on ApiException catch (e) {
      // 401 = сервер не знает это устройство. Живой случай: первый запуск был
      // без сети, регистрация не прошла, аккаунта на сервере нет — и кнопка
      // отвечала «перезапустите приложение», хотя перезапуск ничего не менял.
      // Регистрируемся заново (токен уже стёрт клиентом при 401) и повторяем
      // ровно один раз.
      if (e.statusCode != 401) rethrow;
      final token = await ref.read(tokenStorageProvider).read();
      if (token != null && token.isNotEmpty) rethrow;
      if (!await _registerDevice()) rethrow;
      next = await ref.read(subscriptionRepositoryProvider).activateTrial();
    }

    await ref.read(accessKeysProvider.notifier).refresh();
    final keys = ref.read(accessKeysProvider).value ?? const <AccessKey>[];
    for (final key in keys) {
      final source = ConnectionSource.fromAccessKey(key);
      if (source != null && source.isUsable) {
        await ref.read(activeSourceProvider.notifier).select(source);
        break;
      }
    }

    state = AsyncData(next);
    await ref.read(configRepositoryProvider).saveSubscription(next);

    ref.read(notificationServiceProvider).push(
          title: 'Пробный период активирован',
          body: '3 дня полного доступа, лимит 2 ГБ. Ключ уже добавлен — '
              'нажмите кнопку подключения на главном экране.',
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

  /// Регистрирует устройство на сервере и сохраняет токен.
  ///
  /// Нужен как страховка: любой запрос, требующий токен (пробный период,
  /// ключи, статистика), без регистрации получает 401. Возвращает false,
  /// если связи нет — тогда вызывающий код показывает ошибку как раньше.
  Future<bool> _registerDevice() async {
    try {
      final deviceId = await ref.read(identityProvider.future);
      final fingerprint = await DeviceFingerprint.get();
      final result = await ref.read(authRepositoryProvider).autoRegister(
            deviceId: deviceId,
            fingerprint: fingerprint,
          );
      await ref.read(tokenStorageProvider).write(result.accessToken);
      ref.read(loggerProvider).info(
            'Устройство зарегистрировано повторно (код $deviceId)',
            source: 'auth',
          );
      return true;
    } catch (e) {
      ref.read(loggerProvider).warn('Повторная регистрация не удалась: $e',
          source: 'auth');
      return false;
    }
  }
}
