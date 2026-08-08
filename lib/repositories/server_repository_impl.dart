import '../core/utils/app_logger.dart';
import '../domain/repositories/server_repository.dart';
import '../models/server.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// Server repository backed by the backend API (`GET /servers`) with a
/// graceful fallback to the local static catalog when the API is
/// unreachable (offline mode, tests, backend not deployed).
class ApiServerRepository implements ServerRepository {
  ApiServerRepository({
    required ApiClient api,
    required ServerRepository fallback,
    AppLogger? logger,
  })  : _api = api,
        _fallback = fallback,
        _logger = logger;

  final ApiClient _api;
  final ServerRepository _fallback;
  final AppLogger? _logger;

  @override
  Future<List<Server>> getServers() async {
    try {
      final data = await _api.get('/servers');
      if (data is! List) {
        throw const ApiException('Unexpected servers response',
            code: 'BAD_RESPONSE');
      }
      return data
          .map((item) => Server.fromJson(_asMap(item)))
          .toList();
    } on ApiException catch (e) {
      _logger?.warn(
        'Servers API unavailable ($e) — using local catalog',
        source: 'api',
      );
      return _fallback.getServers();
    }
  }

  @override
  Future<Server?> getById(String id) async {
    try {
      final servers = await getServers();
      for (final server in servers) {
        if (server.id == id) return server;
      }
      return null;
    } catch (_) {
      return _fallback.getById(id);
    }
  }

  Map<String, Object?> _asMap(dynamic item) {
    if (item is! Map) {
      throw const ApiException('Unexpected server item', code: 'BAD_RESPONSE');
    }
    return Map<String, Object?>.from(item);
  }
}
