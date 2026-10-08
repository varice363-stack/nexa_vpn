import '../domain/repositories/subscription_repository.dart';
import '../models/premium_plan.dart';
import '../models/server_plan.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [SubscriptionRepository] backed by the Morok VPN API.
///
/// Maps the backend subscription list onto the client [SubscriptionState].
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<SubscriptionState> getCurrent() async {
    final data = await _api.get('/subscriptions/me');
    if (data is! List) {
      throw const ApiException('Unexpected subscriptions response',
          code: 'BAD_RESPONSE');
    }

    for (final item in data) {
      final json = Map<String, Object?>.from(item as Map);
      final status = json['status'] as String?;
      // TRIAL — тоже действующая подписка. Раньше учитывался только ACTIVE,
      // поэтому после активации пробного экран снова рисовал «предложение».
      final usable = status == 'ACTIVE' || status == 'TRIAL';
      if (!usable) continue;

      final expiresRaw = json['expiresAt'] as String?;
      final expiresAt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
      final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
      if (expired) continue;

      final code = (json['plan'] as String?) ?? '';
      final isTrial = status == 'TRIAL' || code == 'TRIAL';

      return SubscriptionState(
        tier: isTrial ? SubscriptionTier.standard : tierFor(code),
        planId: code,
        expiresAt: expiresAt,
        isTrialActive: isTrial,
      );
    }
    return const SubscriptionState();
  }

  /// Тариф по коду плана из базы (MONTHLY / QUARTERLY / YEARLY / TRIAL).
  static SubscriptionTier tierFor(String code) {
    if (code.isEmpty) return SubscriptionTier.free;
    if (code.contains('YEAR') || code.contains('ANNUAL')) {
      return SubscriptionTier.premium;
    }
    return SubscriptionTier.standard;
  }

  @override
  Future<SubscriptionState> activateTrial() async {
    final data = await _api.post('/billing/trial/activate');
    if (data is! Map) {
      throw const ApiException('Unexpected trial response',
          code: 'BAD_RESPONSE');
    }
    final json = Map<String, Object?>.from(data);
    final expiresRaw = json['expiresAt'] as String?;
    return SubscriptionState(
      tier: SubscriptionTier.standard,
      planId: 'trial',
      expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
      isTrialActive: true,
    );
  }

  @override
  Future<List<ServerPlan>> getPlans() async {
    final data = await _api.get('/plans');
    if (data is! List) {
      throw const ApiException('Unexpected plans response',
          code: 'BAD_RESPONSE');
    }
    return data
        .map((item) => ServerPlan.fromJson(Map<String, Object?>.from(item as Map)))
        .where((plan) => plan.isActive)
        .toList();
  }
}
