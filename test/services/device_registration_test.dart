import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:morok_vpn/domain/repositories/key_storage.dart';
import 'package:morok_vpn/repositories/auth_repository_impl.dart';
import 'package:morok_vpn/services/api/api_client.dart';
import 'package:morok_vpn/services/api/token_storage.dart';
import 'package:morok_vpn/services/identity/device_fingerprint.dart';

class _MemoryKeyStorage implements KeyStorage {
  final Map<String, String> rows = {};
  @override
  Future<void> write(String key, String value) async => rows[key] = value;
  @override
  Future<String?> read(String key) async => rows[key];
  @override
  Future<void> delete(String key) async => rows.remove(key);
  @override
  Future<bool> has(String key) async => rows.containsKey(key);
}

/// Регрессия 08.10.2026: код устройства в приложении — 25 символов
/// («MOROK-XXXX-XXXX-XXXX-XXXX»), а сервер принимал максимум 24. Регистрация
/// отвечала 400 на каждом реальном запуске: телефон оставался гостем, пробный
/// период не выдавался. Тест держит настоящий формат кода и отправку признака
/// устройства в теле запроса.
void main() {
  // Каналу платформы нужен инициализированный движок — иначе проверка
  // «нет канала → null» падала бы на самом тесте, а не на коде.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepositoryImpl.autoRegister', () {
    test('отправляет код из 25 символов и признак устройства', () async {
      Map<String, dynamic>? sentBody;
      final client = ApiClient(
        tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'accessToken': 'jwt-1',
              'user': {'id': 'u1', 'email': 'device-x@morok.local'},
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = AuthRepositoryImpl(api: client);

      final result = await repo.autoRegister(
        deviceId: 'MOROK-AAAA-BBBB-CCCC-DDDD',
        platform: 'android',
        fingerprint: 'a' * 64,
      );

      expect(result.accessToken, 'jwt-1');
      expect(sentBody?['deviceId'], 'MOROK-AAAA-BBBB-CCCC-DDDD');
      expect((sentBody?['deviceId'] as String).length, 25);
      expect(sentBody?['fingerprint'], 'a' * 64);
    });

    test('без признака устройства регистрация всё равно проходит', () async {
      Map<String, dynamic>? sentBody;
      final client = ApiClient(
        tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'accessToken': 'jwt-2',
              'user': {'id': 'u2', 'email': 'device-y@morok.local'},
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = AuthRepositoryImpl(api: client);

      await repo.autoRegister(deviceId: 'MOROK-AAAA-BBBB-CCCC-DDDD');

      expect(sentBody?.containsKey('fingerprint'), isFalse);
    });
  });

  group('DeviceFingerprint', () {
    setUp(DeviceFingerprint.resetCacheForTests);

    test('в среде без нативного канала возвращает null, а не падает',
        () async {
      expect(await DeviceFingerprint.get(), isNull);
    });
  });
}
