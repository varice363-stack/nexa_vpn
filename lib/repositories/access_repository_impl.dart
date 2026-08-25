import '../domain/repositories/access_repository.dart';
import '../models/access_key.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [AccessRepository] backed by the Nexa VPN API.
class AccessRepositoryImpl implements AccessRepository {
  AccessRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<AccessKey>> getKeys() async {
    final data = await _api.get('/provisioning');
    if (data is! List) {
      throw const ApiException('Unexpected keys response', code: 'BAD_RESPONSE');
    }
    return data
        .map((item) =>
            AccessKey.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
  }

  @override
  Future<AccessKey?> getActiveKey() async {
    final data = await _api.get('/provisioning/active');
    if (data == null) return null;
    return AccessKey.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<AccessKey> redeemCode(String code, {String? deviceId}) async {
    final data = await _api.post(
      '/provisioning/redeem',
      body: {
        'code': code,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
    );
    return AccessKey.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<AccessKey> claimCode(String code) async {
    final data = await _api.post('/provisioning/claim', body: {'code': code});
    return AccessKey.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<AccessKey> issueCode({String? name, int? durationDays}) async {
    final data = await _api.post(
      '/provisioning/issue',
      body: {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        // 0 means lifetime; the backend treats missing the same way.
        'durationDays': durationDays ?? 0,
      },
    );
    return AccessKey.fromJson(Map<String, Object?>.from(data as Map));
  }

  @override
  Future<List<AccessKey>> getAllKeys() async {
    final data = await _api.get('/provisioning/all');
    if (data is! List) {
      throw const ApiException('Unexpected keys response', code: 'BAD_RESPONSE');
    }
    return data
        .map((item) =>
            AccessKey.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
  }
}
