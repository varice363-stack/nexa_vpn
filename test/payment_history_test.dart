import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/screens/payments/payment_history_screen.dart';
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

const _historyJson = '''
[
  {"id":"tx1","status":"PAID","amount":11.99,"currency":"USD",
   "provider":"INTERNAL","planName":"Nexa 30 Days",
   "createdAt":"2026-08-01T10:00:00.000Z"},
  {"id":"tx2","status":"FAILED","amount":11.99,"currency":"USD",
   "provider":"INTERNAL","planName":"Nexa 30 Days",
   "createdAt":"2026-08-02T10:00:00.000Z"}
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
      child: const MaterialApp(home: PaymentHistoryScreen()),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('history loading state', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/billing/transactions')) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return http.Response(_historyJson, 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Loading payments…'), findsOneWidget);

    await _settle(tester);
    expect(find.text('Nexa 30 Days'), findsNWidgets(2));
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('history empty state', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/billing/transactions')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _boot(tester, client: client);
    await _settle(tester);

    expect(find.text('No payments yet'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('history offline → empty with message', (tester) async {
    final client = MockClient((_) async => http.Response(
        '{"message":"down"}', 503,
        headers: {'content-type': 'application/json'}));

    await _boot(tester, client: client);
    await _settle(tester);

    expect(find.text('No payments yet'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
