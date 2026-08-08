import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/repositories/billing_repository_impl.dart';
import 'package:nexa_vpn/screens/premium/premium_screen.dart';
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

const _plansJson = '''
[
  {"id":"p1","code":"MONTHLY","name":"Nexa 30 Days","description":null,
   "durationDays":30,"price":11.99,"currency":"USD","isActive":true},
  {"id":"p2","code":"YEARLY","name":"Nexa 365 Days","description":null,
   "durationDays":365,"price":71.88,"currency":"USD","isActive":true}
]
''';

Future<ProviderScope> _boot(
  WidgetTester tester, {
  required MockClient client,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final scope = ProviderScope(
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
    child: const MaterialApp(home: PremiumScreen()),
  );
  await tester.pumpWidget(scope);
  return scope;
}

void main() {
  testWidgets('plans loading → loaded (guest sees sign-in CTA)', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/plans')) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });
    await _boot(tester, client: client);

    // Loading state (response is delayed).
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Loading plans…'), findsOneWidget);

    // Loaded state.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nexa 30 Days'), findsOneWidget);
    expect(find.text('Nexa 365 Days'), findsOneWidget);
    expect(find.text('USD 11.99'), findsOneWidget);
    // Guest → sign-in CTA instead of checkout.
    expect(find.text('Sign in to subscribe'), findsOneWidget);

    // Drain any pending timers before teardown.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('offline → static fallback plans with retry', (tester) async {
    final client = MockClient((_) async => http.Response(
        '{"message":"down"}', 503,
        headers: {'content-type': 'application/json'}));
    await _boot(tester, client: client);

    await tester.pump(const Duration(milliseconds: 100));
    // Static fallback catalog is used, so plans still render.
    expect(find.textContaining('Nexa'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });

  test('checkout success — BillingRepository returns CheckoutResult',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/billing/checkout');
      final body = request.body;
      expect(body, contains('planId'));
      return http.Response(
        '{"transactionId":"tx1","status":"PENDING",'
        '"checkoutUrl":"https://mock-pay.nexa.app/checkout/tx1"}',
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final repo = BillingRepositoryImpl(
      api: ApiClient(
        tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
        httpClient: client,
      ),
    );

    final result = await repo.createCheckout('p1');

    expect(result.transactionId, 'tx1');
    expect(result.status, 'PENDING');
    expect(result.checkoutUrl, contains('mock-pay.nexa.app'));
  });

  test('checkout failure — BillingRepository throws ApiException', () async {
    final client = MockClient((_) async =>
        http.Response('{"message":"billing down"}', 500,
            headers: {'content-type': 'application/json'}));
    final repo = BillingRepositoryImpl(
      api: ApiClient(
        tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
        httpClient: client,
      ),
    );

    await expectLater(repo.createCheckout('p1'), throwsA(isA<Exception>()));
  });
}
