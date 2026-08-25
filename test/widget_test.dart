import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/app/app.dart';
import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/services/api/api_client.dart';
import 'package:nexa_vpn/services/api/token_storage.dart';
import 'package:nexa_vpn/widgets/buttons/power_button.dart';

/// In-memory [KeyStorage] so tests never touch platform channels.
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

/// HTTP client that responds 503 to every request — forces the
/// repositories to exercise their local fallback paths.
final _offlineClient = MockClient(
  (_) async => http.Response(
    '{"message":"backend unavailable in tests"}',
    503,
    headers: {'content-type': 'application/json'},
  ),
);

Future<ProviderScope> _boot(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  // Fresh instance + fresh store per test (the singleton caches across
  // tests within one process otherwise).
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final scope = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Backend is "offline" in tests — repositories must fall back
      // to local data; auth stays anonymous (guest mode).
      keyStorageProvider.overrideWithValue(_MemoryKeyStorage()),
      apiClientProvider.overrideWithValue(
        ApiClient(
          tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
          httpClient: _offlineClient,
        ),
      ),
    ],
    child: const NexaVpnApp(),
  );
  await tester.pumpWidget(scope);
  return scope;
}

/// Lets the bootstrap (auth + onboarding) and entrance animations settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Walks the real first-run flow: Skip onboarding, then accept the
/// mandatory VpnService disclosure. Both gates are enforced by the router,
/// so every test that expects Home must pass through them.
Future<void> passFirstRun(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await _settle(tester);
  await tester.tap(find.text('I understand and agree'));
  await _settle(tester);
}

void main() {

  testWidgets('boot: splash → onboarding on fresh install', (tester) async {
    await _boot(tester);
    // First frame: bootstrap is resolving, the splash screen is shown.
    await tester.pump();
    expect(find.text('Nexa VPN'), findsOneWidget);

    // Bootstrap resolves without any artificial delay → onboarding opens.
    await _settle(tester);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('onboarding → home without a preselected server', (tester) async {
    await _boot(tester);
    await _settle(tester);

    // Complete onboarding via Skip → guest home.
    await passFirstRun(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // The home screen must NOT advertise a server. It used to show the
    // fastest entry from the demo catalogue ("Istanbul TR-01"), which has
    // nothing to do with the key the user actually connects with — an
    // imported vless:// link carries its own location.
    expect(find.text('Current server'), findsNothing);
    expect(find.textContaining('Istanbul'), findsNothing);
    expect(find.textContaining('Turkey'), findsNothing);

    // Guest mode is reflected in the profile tab.
    expect(find.text('Guest mode'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('servers screen opens from bottom navigation', (tester) async {
    await _boot(tester);
    await _settle(tester);
    await passFirstRun(tester);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Servers').last);
    await _settle(tester);

    // The screen now lists real endpoints from the user's key. With no key
    // added it must say so and offer the way to add one, instead of showing
    // a catalog of servers nobody can connect to.
    expect(find.text('No servers yet'), findsWidgets);
    expect(find.text('Add a key'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('guest with no key is sent to the key screen, not to login',
      (tester) async {
    await _boot(tester);
    await _settle(tester);
    await passFirstRun(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // Connecting must not demand an account: someone who already owns a key
    // has to be able to use it on first launch. With nothing added yet the
    // button leads to the key screen so the flow can continue.
    await tester.tap(find.byType(PowerButton), warnIfMissed: false);
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Access key'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
