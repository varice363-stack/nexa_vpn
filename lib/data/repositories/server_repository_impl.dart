import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/repositories/server_repository.dart';
import '../../models/server.dart';
import '../datasources/server_catalog.dart';

/// Server repository backed by the static catalog.
///
/// Simulates network latency and adds realistic ping jitter so the UI
/// behaves exactly as with a live backend. Replace the body with an API
/// call when the backend contract is available — the interface stays.
class ServerRepositoryImpl implements ServerRepository {
  ServerRepositoryImpl({this.catalogDelay = AppConstants.serverCatalogDelay});

  final int catalogDelay;
  final Random _random = Random();

  @override
  Future<List<Server>> getServers() async {
    await Future<void>.delayed(Duration(milliseconds: catalogDelay));
    return kServers
        .map((server) => server.copyWith(
              ping: max(1, server.ping + _random.nextInt(9) - 4),
            ))
        .toList();
  }

  @override
  Future<Server?> getById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    for (final server in kServers) {
      if (server.id == id) return server;
    }
    throw AppException('Server not found: $id', code: 'SERVER_NOT_FOUND');
  }
}
