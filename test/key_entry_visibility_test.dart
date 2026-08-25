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

/// Regression guard for a shipped bug: `HomeAccessSection` returned
/// `SizedBox.shrink()` for anonymous users, which hid the ONLY entry point
/// to `/key`. Redeeming a key does not require an account, so a guest —
/// the most common first-run state — could not find where to paste a key.
///
/// These tests assert the entry point is reachable without signing in.

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

/// Backend is unreachable in tests → auth stays anonymous (guest mode).
final _offlineClient = MockClient(
  (_) async => http.Response(
    '{"message":"backend unavailable in tests"}',
    503,
    headers: {'content-type': 'application/json'},
  ),
);

Future<void> _boot(WidgetTester tester) async {
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
            httpClient: _offlineClient,
          ),
        ),
      ],
      child: const NexaVpnApp(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Onboarding + the mandatory VpnService disclosure both gate the router.
Future<void> _passFirstRun(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await _settle(tester);
  await tester.tap(find.text('I understand and agree'));
  await _settle(tester);
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('guest sees the "I have a key" entry point on home',
      (tester) async {
    await _boot(tester);
    await _settle(tester);
    await _passFirstRun(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // The bug: this used to be findsNothing for anonymous users.
    expect(find.text('I have a key'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('guest can open the key entry screen and reach the input field',
      (tester) async {
    await _boot(tester);
    await _settle(tester);
    await _passFirstRun(tester);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('I have a key'));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // The screen must actually open — not bounce back to login.
    expect(find.text('Access key'), findsOneWidget);
    expect(find.byType(EditableText), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('settings exposes a permanent way to add a key', (tester) async {
    await _boot(tester);
    await _settle(tester);
    await _passFirstRun(tester);
    await tester.pump(const Duration(milliseconds: 500));

    // Settings lives inside the Profile tab.
    await tester.tap(find.text('Profile').last);
    await _settle(tester);
    await tester.ensureVisible(find.text('Settings').last);
    await _settle(tester);
    await tester.tap(find.text('Settings').last, warnIfMissed: false);
    await _settle(tester);
    await _settle(tester);

    // Home hides its CTA once a key is active; settings must not.
    expect(find.text('I have a key'), findsOneWidget);

    await _teardown(tester);
  });
}
