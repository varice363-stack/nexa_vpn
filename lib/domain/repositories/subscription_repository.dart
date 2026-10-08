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

  /// GET /plans — каталог тарифов с ценами из базы.
  Future<List<ServerPlan>> getPlans();
}
