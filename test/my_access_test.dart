import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/screens/access/my_access_screen.dart';
import 'package:nexa_vpn/services/api/api_client.dart';
import 'package:nexa_vpn/services/api/token_storage.dart';

class _MemoryKeyStorage implements KeyStorage {
  final Map<String, String> _values = {};
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<bool> has(String key) async => _values.containsKey(key);
}

String _keyJson(String status, {bool withConfig = true}) => '''
[
  {
    "id":"k1",
    "name":"My iPhone",
    "protocol":"VLESS",
    "status":"$status",
    "createdAt":"2026-08-01T00:00:00.000Z",
    "expiresAt":${status == 'ACTIVE' ? '"2026-09-01T00:00:00.000Z"' : '"2026-08-01T00:00:00.000Z"'},
    "lastUsedAt":null,
    "deviceId":null,
    "deviceCount":1,
    "server":${withConfig ? '''
    {
      "id":"s1",
      "name":"Istanbul TR-01",
      "country":"Turkey",
      "countryCode":"TR",
      "city":"Istanbul",
      "ip":"185.65.134.22"
    }''' : 'null'},
    "config":${withConfig
        ? '{"format":"vless","uri":"vless://11111111-2222-3333-4444-555555555555@185.65.134.22:443?encryption=none&type=tcp&security=none#My%20iPhone","qrPayload":"vless://11111111-2222-3333-4444-555555555555@185.65.134.22:443?encryption=none&type=tcp&security=none#My%20iPhone"}'
        : '{"format":"vless","uri":null,"qrPayload":null}'}
  }
]
''';

Future<void> _boot(
  WidgetTester tester, {
  required MockClient client,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        keyStorageProvider.overrideWithValue(_MemoryKeyStorage()),
        apiClientProvider.overrideWithValue(
          ApiClient(
            tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
            httpClient: client,
          ),
        ),
      ],
      child: const MaterialApp(home: MyAccessScreen()),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('active key — VLESS config panel with Copy/QR/Share',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/provisioning')) {
        return http.Response(_keyJson('ACTIVE'), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await _settle(tester);

    // Config panel is shown for an ACTIVE key.
    expect(find.text('Active VLESS configuration'), findsOneWidget);
    expect(find.text('Copy VLESS'), findsOneWidget);
    expect(find.text('Show QR'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    // Server + protocol + expiry.
    expect(find.textContaining('Istanbul TR-01'), findsOneWidget);
    expect(find.text('VLESS'), findsWidgets);
    expect(find.textContaining('Sep 1'), findsWidgets);
  });

  testWidgets('QR dialog opens with the config payload', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/provisioning')) {
        return http.Response(_keyJson('ACTIVE'), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await _settle(tester);

    await tester.tap(find.text('Show QR'));
    await _settle(tester);

    expect(find.text('Scan with any VLESS client'), findsOneWidget);
    // QrImageView widget is present.
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('expired key — no config panel, warning banner shown',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/provisioning')) {
        return http.Response(_keyJson('EXPIRED', withConfig: false), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await _settle(tester);

    expect(find.text('Active VLESS configuration'), findsNothing);
    expect(find.textContaining('No active access'), findsOneWidget);
    expect(find.text('Copy VLESS'), findsNothing);
  });

  testWidgets('revoked key — no config panel', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/provisioning')) {
        return http.Response(_keyJson('REVOKED', withConfig: false), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await _settle(tester);

    expect(find.text('Active VLESS configuration'), findsNothing);
    expect(find.text('Copy VLESS'), findsNothing);
  });

  testWidgets('offline — empty state with retry message', (tester) async {
    final client = MockClient((_) async => http.Response(
        '{"message":"down"}', 503,
        headers: {'content-type': 'application/json'}));

    await _boot(tester, client: client);
    await _settle(tester);

    expect(find.text('No access keys yet'), findsWidgets);
  });

  testWidgets('active key without config — "Configuration unavailable" shown',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/provisioning')) {
        return http.Response(_keyJson('ACTIVE', withConfig: false), 200,
            headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await _settle(tester);

    // ACTIVE key exists but has no config (assigned server missing) →
    // safe "unavailable" state, no Copy/QR/Share, no fake URI.
    expect(find.text('Configuration unavailable'), findsOneWidget);
    expect(find.text('Copy VLESS'), findsNothing);
    expect(find.text('Show QR'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });
}
