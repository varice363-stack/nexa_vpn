import '../../models/server.dart';

/// Contract of the server catalog source.
abstract class ServerRepository {
  /// Returns all available servers.
  ///
  /// Backed by the backend API (`GET /servers`).
  Future<List<Server>> getServers();

  /// Resolves a single server by id, or `null`.
  Future<Server?> getById(String id);
}
