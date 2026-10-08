import '../../models/premium_plan.dart';
import '../../models/server_plan.dart';

/// Subscription contract (backend `/subscriptions`, `/billing`, `/plans`).
abstract class SubscriptionRepository {
  /// GET /subscriptions/me — resolves the current effective state
  /// (premium if any ACTIVE subscription exists, TRIAL included).
  Future<SubscriptionState> getCurrent();

  /// POST /billing/trial/activate — пробный период.
  ///
  /// Сервер создаёт TRIAL-подписку и **настоящий** ACTIVE-ключ доступа на
  /// 3 дня с лимитом 2 ГБ, а также немедленно выкладывает его ядру. Возвращает
  /// состояние подписки с датой окончания, чтобы экран показал реальный
  /// обратный отсчёт.
  Future<SubscriptionState> activateTrial();

  /// POST /billing/referral/apply — ввод кода друга.
  ///
  /// Условие программы одно и без процентов: приглашённый получает неделю
  /// бесплатного доступа. Если доступ уже есть — неделя добавляется к нему.
  /// Возвращает состояние подписки с новым сроком, чтобы экран показал
  /// правду, а не «спасибо, всё готово».
  Future<SubscriptionState> applyReferral(String code);

  /// GET /plans — каталог тарифов с ценами из базы.
  Future<List<ServerPlan>> getPlans();
}
