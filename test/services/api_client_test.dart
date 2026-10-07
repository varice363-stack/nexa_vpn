import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:morok_vpn/domain/repositories/key_storage.dart';
import 'package:morok_vpn/services/api/api_client.dart';
import 'package:morok_vpn/services/api/token_storage.dart';

class _MemoryKeyStorage implements KeyStorage {
  final Map<String, String> _rows = {};
  @override
  Future<void> write(String key, String value) async => _rows[key] = value;
  @override
  Future<String?> read(String key) async => _rows[key];
  @override
  Future<void> delete(String key) async => _rows.remove(key);
  @override
  Future<bool> has(String key) async => _rows.containsKey(key);
}

TokenStorage _storageWith(String? token) {
  final storage = _MemoryKeyStorage();
  if (token != null) storage._rows[TokenStorage.tokenKey] = token;
  return TokenStorage(storage: storage);
}

void main() {
  group('ApiClient / 401', () {
    test(
        'просит перевыпустить токен и повторяет запрос, а не выбрасывает сессию',
        () async {
      var refreshes = 0;
      final seen = <String?>[];
      final client = ApiClient(
        tokenStorage: _storageWith('stale-jwt'),
        httpClient: MockClient((request) async {
          seen.add(request.headers['Authorization']);
          if (seen.length == 1) {
            return http.Response(
              jsonEncode({'message': 'Unauthorized'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      client.refreshToken = () async {
        refreshes++;
        await client.tokenStorage.write('fresh-jwt');
        return true;
      };

      final result = await client.get('/banners/1/upload-status');

      expect(result, {'ok': true});
      expect(refreshes, 1);
      // вторая попытка обязана идти уже с новым токеном — иначе повтор
      // повторяет ошибку, а не чинит её
      expect(seen, ['Bearer stale-jwt', 'Bearer fresh-jwt']);
    });

    test('если токен обновить нечем — ошибка, но без бесконечного повтора',
        () async {
      var calls = 0;
      final client = ApiClient(
        tokenStorage: _storageWith('stale-jwt'),
        httpClient: MockClient((request) async {
          calls++;
          return http.Response('{"message":"nope"}', 401,
              headers: {'content-type': 'application/json'});
        }),
      );
      client.refreshToken = () async => false;

      await expectLater(client.get('/auth/me'), throwsA(isA<Exception>()));
      expect(calls, 1);
    });
  });

  group('ApiClient / заголовки', () {
    test('JWT подставляется, Content-Type задан', () async {
      final client = ApiClient(
        tokenStorage: _storageWith('abc'),
        httpClient: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer abc');
          expect(r.headers['Content-Type'], contains('application/json'));
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      await client.post('/x', body: const {'a': 1});
    });

    test('заголовок владельца не светится в публичной сборке', () async {
      // kOwnerCode в тестах не задан (--dart-define отсутствует) — заголовка
      // быть не должно. Это и есть защита публичного APK: админки в нём нет.
      final client = ApiClient(
        tokenStorage: _storageWith(null),
        httpClient: MockClient((r) async {
          expect(r.headers.containsKey('X-Owner-Code'), isFalse);
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      await client.get('/banners');
    });
  });
}
