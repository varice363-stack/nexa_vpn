import '../../models/checkout_result.dart';
import '../../models/mock_pay_result.dart';
import '../../models/payment_transaction.dart';
import '../../models/subscription_plan.dart';
import '../../models/trial_status.dart';

/// Billing contract (backend `/plans`, `/billing`).
abstract class BillingRepository {
  /// GET /plans — active subscription plans.
  Future<List<SubscriptionPlan>> getPlans();

  /// POST /billing/checkout — initiates a (mock) checkout for a plan.
  Future<CheckoutResult> createCheckout(String planId);

  /// POST /billing/mock-pay/:transactionId — confirms a mock payment.
  Future<MockPayResult> mockPay(String transactionId);

  /// GET /billing/transactions — own payment transactions.
  Future<List<PaymentTransaction>> getTransactions();

  /// GET /billing/transactions/:id — single transaction (status check).
  Future<PaymentTransaction> getTransaction(String id);

  /// GET /billing/trial/status — trial availability.
  Future<TrialStatus> getTrialStatus();

  /// POST /billing/trial/activate — start the 3-day trial.
  Future<void> activateTrial();
}
