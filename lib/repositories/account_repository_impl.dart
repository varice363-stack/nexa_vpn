import '../domain/repositories/account_repository.dart';
import '../services/api/api_client.dart';

/// [AccountRepository] backed by the Nexa VPN API.
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Errors propagate as ApiException so the UI can show the real reason
    // (401 = wrong current password, 400 = new password too short).
    await _api.patch(
      '/account',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
