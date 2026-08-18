import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/models/auth_user.dart';
import 'package:nexa_vpn/providers/auth_providers.dart';
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

/// Fake authenticated notifier — the payment flow requires a logged-in user.
class _AuthedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 'u1', email: 'u@test.dev', role: UserRole.user);
}

Future<void> _bootAuthed(
  WidgetTester tester, {
  required MockClient client,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // Tall viewport so the payment card is visible without scrolling.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PremiumScreen()),
      GoRoute(
        path: '/access',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('My Access'))),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Login'))),
      ),
    ],
  );

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
        authProvider.overrideWith(() => _AuthedAuthNotifier()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

Future<void> _pumpSettle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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


  testWidgets('payment success — checkout → mock-pay → access activated',
      (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/plans')) {
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/billing/checkout')) {
        return http.Response(
          '{"transactionId":"tx1","status":"PENDING",'
          '"checkoutUrl":"https://mock-pay.nexa.app/checkout/tx1"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.contains('/billing/mock-pay/')) {
        return http.Response(
          '{"status":"PAID","subscription":"ACTIVE","accessKey":"ACTIVE",'
          '"subscriptionId":"sub1"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      // Subscription + keys refresh after payment.
      if (path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/provisioning')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _bootAuthed(tester, client: client);
    await _pumpSettle(tester);

    // Plans are loaded; the first plan is pre-selected.
    expect(find.text('Nexa 30 Days'), findsOneWidget);
    expect(find.textContaining('Get Premium'), findsOneWidget);

    // Step 1: checkout.
    await tester.tap(find.textContaining('Get Premium'));
    await _pumpSettle(tester);

    // Step 2: mock payment card appears.
    expect(find.text('Payment (demo)'), findsOneWidget);
    expect(find.text('Pay now (demo)'), findsOneWidget);

    // Step 3: confirm the mock payment.
    await tester.tap(find.text('Pay now (demo)'));
    await _pumpSettle(tester);

    // Step 4: navigated to My Access.
    expect(find.text('My Access'), findsOneWidget);
  });

  testWidgets('payment failure — shows an error, stays on Premium',
      (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/plans')) {
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/billing/checkout')) {
        return http.Response(
          '{"transactionId":"tx1","status":"PENDING","checkoutUrl":null}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.contains('/billing/mock-pay/')) {
        return http.Response('{"message":"payment provider down"}', 500,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _bootAuthed(tester, client: client);
    await _pumpSettle(tester);

    await tester.tap(find.textContaining('Get Premium'));
    await _pumpSettle(tester);

    await tester.tap(find.text('Pay now (demo)'));
    await _pumpSettle(tester);

    // Error shown, still on the Premium screen.
    expect(find.textContaining('Payment failed'), findsWidgets);
    expect(find.text('My Access'), findsNothing);
    expect(find.text('Pay now (demo)'), findsOneWidget);
  });

  testWidgets('trial — card visible when available, activation succeeds',
      (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/plans')) {
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/billing/trial/status')) {
        return http.Response(
          '{"available":true,"used":false,"expiresAt":null}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/billing/trial/activate')) {
        return http.Response(
          '{"status":"TRIAL","subscriptionId":"sub-t","expiresAt":null,'
          '"accessKey":{"id":"k-t","status":"ACTIVE"}}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/provisioning')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _bootAuthed(tester, client: client);
    await _pumpSettle(tester);

    // Trial card is visible for a fresh account.
    expect(find.text('3-day free trial'), findsOneWidget);

    // Start the trial.
    await tester.tap(find.text('Start trial'));
    await _pumpSettle(tester);

    // Snackbar confirmation appears.
    expect(find.text('Trial started — 3 days of access!'), findsOneWidget);
  });

  testWidgets('trial — card hidden when trial was used', (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/plans')) {
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/billing/trial/status')) {
        return http.Response(
          '{"available":false,"used":true,"expiresAt":"2026-08-01T00:00:00.000Z"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await _bootAuthed(tester, client: client);
    await _pumpSettle(tester);

    expect(find.text('3-day free trial'), findsNothing);
    expect(find.text('Nexa 30 Days'), findsOneWidget);
  });

  testWidgets('real checkout — open payment page + check status (success)',
      (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/plans')) {
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/billing/checkout')) {
        // Real provider checkout returns an external URL.
        return http.Response(
          '{"transactionId":"tx1","status":"PENDING",'
          '"checkoutUrl":"https://yoomoney.ru/checkout/123"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.contains('/billing/transactions/tx1')) {
        return http.Response(
          '{"id":"tx1","status":"PAID","amount":11.99,"currency":"USD",'
          '"provider":"YOOKASSA"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/subscriptions/me')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/provisioning')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    await _bootAuthed(tester, client: client);
    await _pumpSettle(tester);

    await tester.tap(find.textContaining('Get Premium'));
    await _pumpSettle(tester);

    // Real provider UI (not the demo button).
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Open payment page'), findsOneWidget);
    expect(find.text('I have paid — check status'), findsOneWidget);
    expect(find.text('Pay now (demo)'), findsNothing);

    // Simulate: user paid on the provider page → check status → success.
    await tester.scrollUntilVisible(
      find.text('I have paid — check status'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('I have paid — check status'));
    await _pumpSettle(tester);

    expect(find.text('My Access'), findsOneWidget);
  });

  testWidgets('real checkout — pending status keeps the user on Premium',
      (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/plans')) {
        return http.Response(_plansJson, 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/billing/checkout')) {
        return http.Response(
          '{"transactionId":"tx1","status":"PENDING",'
          '"checkoutUrl":"https://yoomoney.ru/checkout/123"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.contains('/billing/transactions/tx1')) {
        return http.Response(
          '{"id":"tx1","status":"PENDING","amount":11.99,"currency":"USD",'
          '"provider":"YOOKASSA"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await _bootAuthed(tester, client: client);
    await _pumpSettle(tester);

    await tester.tap(find.textContaining('Get Premium'));
    await _pumpSettle(tester);
    await tester.scrollUntilVisible(
      find.text('I have paid — check status'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('I have paid — check status'));
    await _pumpSettle(tester);

    // Still on Premium with a pending notice; no fake success.
    expect(find.text('My Access'), findsNothing);
    expect(find.textContaining('waiting for confirmation'), findsOneWidget);
  });
}
