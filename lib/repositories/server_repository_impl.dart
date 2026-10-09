import '../core/utils/app_logger.dart';
import '../domain/repositories/server_repository.dart';
import '../models/server.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// Список серверов с бэкенда (`GET /servers`).
///
/// Если бэкенд недоступен, ошибка уходит наверх как есть. Раньше здесь
/// подставлялся встроенный каталог с выдуманными пингами и загрузкой, и его
/// можно было принять за настоящие серверы.
class ApiServerRepository implements ServerRepository {
  ApiServerRepository({
    required ApiClient api,
    AppLogger? logger,
  })  : _api = api,
        _logger = logger;

  final ApiClient _api;
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
      _logger?.warn('Servers API unavailable ($e)', source: 'api');
      rethrow;
    }
  }

  @override
  Future<Server?> getById(String id) async {
    final servers = await getServers();
    for (final server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  Map<String, Object?> _asMap(dynamic item) {
    if (item is! Map) {
      throw const ApiException('Unexpected server item', code: 'BAD_RESPONSE');
    }
    return Map<String, Object?>.from(item);
  }
}
