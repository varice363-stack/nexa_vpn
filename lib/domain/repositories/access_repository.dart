import '../../models/access_key.dart';

/// Access keys contract (backend `/provisioning`).
abstract class AccessRepository {
  /// GET /provisioning — all keys of the current user.
  Future<List<AccessKey>> getKeys();

  /// GET /provisioning/active — the current active key, or null.
  Future<AccessKey?> getActiveKey();
}
