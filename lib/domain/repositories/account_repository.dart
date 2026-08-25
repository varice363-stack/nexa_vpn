/// Account self-service contract (backend `/account`).
abstract class AccountRepository {
  /// PATCH /account — change the signed-in user's password.
  ///
  /// The backend verifies [currentPassword] before applying [newPassword],
  /// so a stolen session alone cannot take over the account.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
