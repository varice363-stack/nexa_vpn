import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/repositories/server_repository_impl.dart';
import 'package:morok_vpn/services/api/api_client.dart';
import 'package:morok_vpn/services/api/api_exception.dart';

/// Раньше при недоступном бэкенде список серверов подменялся встроенным
/// каталогом с выдуманными пингами. Теперь ошибка видна как есть.
class _DownApi implements ApiClient {
  @override
  Future<dynamic> get(String path) async =>
      throw const ApiException('Нет сети', code: 'NETWORK');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OkApi implements ApiClient {
  _OkApi(this.body);

  final dynamic body;

  @override
  Future<dynamic> get(String path) async => body;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('бэкенд недоступен — ошибка, а не список выдуманных серверов', () async {
    final repo = ApiServerRepository(api: _DownApi());

    await expectLater(repo.getServers(), throwsA(isA<ApiException>()));
  });

  test('getById при недоступном бэкенде тоже ошибка, без каталога', () async {
    final repo = ApiServerRepository(api: _DownApi());

    await expectLater(
      repo.getById('nl-ams-01'),
      throwsA(isA<ApiException>()),
    );
  });

  test('ответ бэкенда разбирается как есть (формат из прода)', () async {
    final repo = ApiServerRepository(
      api: _OkApi([
        {
          'id': '7491a3ee-f0c5-4f02-b3bb-563f54b2e5f1',
          'name': 'MOROK Fast NL-01',
          'country': 'Netherlands',
          'countryCode': 'NL',
          'city': 'Amsterdam',
          'protocol': 'WIREGUARD',
          'load': 0.15,
          'ping': 45,
          'premium': false,
        },
      ]),
    );

    final servers = await repo.getServers();

    expect(servers, hasLength(1));
    expect(servers.single.id, '7491a3ee-f0c5-4f02-b3bb-563f54b2e5f1');
    expect(servers.single.ping, 45);
  });
}
