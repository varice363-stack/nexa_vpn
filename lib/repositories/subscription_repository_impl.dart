import '../domain/repositories/subscription_repository.dart';
import '../models/premium_plan.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [SubscriptionRepository] backed by the Nexa VPN API.
///
/// Maps the backend subscription list onto the client [SubscriptionState]:
/// any ACTIVE subscription → premium tier.
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
      if (json['status'] == 'ACTIVE') {
        final plan = (json['plan'] as String?)?.toLowerCase();
        final expiresAt = json['expiresAt'] as String?;
        return SubscriptionState(
          tier: SubscriptionTier.premium,
          planId: plan,
          expiresAt: expiresAt == null
              ? null
              : DateTime.tryParse(expiresAt),
        );
      }
    }
    return const SubscriptionState();
  }
}
