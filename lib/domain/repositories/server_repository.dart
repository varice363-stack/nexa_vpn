import '../../models/server.dart';

/// Contract of the server catalog source.
abstract class ServerRepository {
  /// Returns all available servers.
  ///
  /// May hit a network backend in the future; today backed by the static
  /// catalog with simulated latency and ping refresh.
  Future<List<Server>> getServers();

  /// Resolves a single server by id, or `null`.
  Future<Server?> getById(String id);
}
