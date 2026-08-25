import '../../models/access_key.dart';

/// Access keys contract (backend `/provisioning`).
abstract class AccessRepository {
  /// GET /provisioning — all keys of the current user.
  Future<List<AccessKey>> getKeys();

  /// GET /provisioning/active — the current active key, or null.
  Future<AccessKey?> getActiveKey();

  /// POST /provisioning/redeem — activates a Nexa code.
  ///
  /// Public on the backend: no account is required, which is the whole
  /// point of the code flow.
  Future<AccessKey> redeemCode(String code, {String? deviceId});

  /// POST /provisioning/claim — binds a redeemed code to the signed-in
  /// account so it survives a reinstall.
  Future<AccessKey> claimCode(String code);

  /// POST /provisioning/issue — mints a sellable code. ADMIN only.
  ///
  /// [durationDays] of 0 (or null) issues a lifetime key.
  Future<AccessKey> issueCode({String? name, int? durationDays});

  /// GET /provisioning/all — every key in the system. ADMIN only.
  Future<List<AccessKey>> getAllKeys();
}
