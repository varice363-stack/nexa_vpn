import '../../models/premium_plan.dart';

/// Subscription contract (backend `/subscriptions`).
abstract class SubscriptionRepository {
  /// GET /subscriptions/me — resolves the current effective state
  /// (premium if any ACTIVE subscription exists).
  Future<SubscriptionState> getCurrent();
}
