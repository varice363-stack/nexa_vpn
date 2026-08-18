import '../domain/repositories/billing_repository.dart';
import '../models/checkout_result.dart';
import '../models/mock_pay_result.dart';
import '../models/payment_transaction.dart';
import '../models/subscription_plan.dart';
import '../models/trial_status.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [BillingRepository] backed by the Nexa VPN API.
class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<SubscriptionPlan>> getPlans() async {
    final data = await _api.get('/plans');
    if (data is! List) {
      throw const ApiException('Unexpected plans response', code: 'BAD_RESPONSE');
    }
    return data
        .map((item) =>
            SubscriptionPlan.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
  }

  @override
  Future<CheckoutResult> createCheckout(String planId) async {
    final data = await _api.post(
      '/billing/checkout',
      body: {'planId': planId},
    );
    return CheckoutResult.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<MockPayResult> mockPay(String transactionId) async {
    final data = await _api.post('/billing/mock-pay/$transactionId');
    return MockPayResult.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<TrialStatus> getTrialStatus() async {
    final data = await _api.get('/billing/trial/status');
    return TrialStatus.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<void> activateTrial() async {
    await _api.post('/billing/trial/activate');
  }

  @override
  Future<PaymentTransaction> getTransaction(String id) async {
    final data = await _api.get('/billing/transactions/$id');
    return PaymentTransaction.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<List<PaymentTransaction>> getTransactions() async {
    final data = await _api.get('/billing/transactions');
    if (data is! List) {
      throw const ApiException('Unexpected transactions response',
          code: 'BAD_RESPONSE');
    }
    return data
        .map((item) =>
            PaymentTransaction.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
  }
}
