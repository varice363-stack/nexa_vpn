import '../../models/checkout_result.dart';
import '../../models/payment_transaction.dart';
import '../../models/subscription_plan.dart';

/// Billing contract (backend `/plans`, `/billing`).
abstract class BillingRepository {
  /// GET /plans — active subscription plans.
  Future<List<SubscriptionPlan>> getPlans();

  /// POST /billing/checkout — initiates a (mock) checkout for a plan.
  Future<CheckoutResult> createCheckout(String planId);

  /// GET /billing/transactions — own payment transactions.
  Future<List<PaymentTransaction>> getTransactions();
}
