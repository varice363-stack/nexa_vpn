import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/app/app.dart';
import 'package:nexa_vpn/app/router/app_router.dart';
import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/screens/about/about_screen.dart';
import 'package:nexa_vpn/screens/home/home_screen.dart';
import 'package:nexa_vpn/screens/profile/profile_screen.dart';
import 'package:nexa_vpn/screens/servers/servers_screen.dart';
import 'package:nexa_vpn/screens/settings/settings_screen.dart';
import 'package:nexa_vpn/services/api/api_client.dart';
import 'package:nexa_vpn/services/api/token_storage.dart';

/// Regression tests for TASK #017 — Android system back gesture.
///
/// The system back must walk the navigation stack one step at a time
/// (C → B → A) and only leave the app from the Home branch.

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

final _offlineClient = MockClient(
  (_) async => http.Response(
    '{"message":"backend unavailable in tests"}',
    503,
    headers: {'content-type': 'application/json'},
  ),
);

late ProviderContainer _container;

Future<void> _boot(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.resetStatic();
  // Onboarding already completed → the app boots straight into the shell.
  SharedPreferences.setMockInitialValues({
    'onboarding_completed': true,
    'nexa_vpn_consent_accepted': true,
  });
  final prefs = await SharedPreferences.getInstance();
  _container = ProviderContainer(
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
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: const NexaVpnApp(),
    ),
  );
  await _settle(tester);
}

GoRouter get _router => _container.read(appRouterProvider);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Simulates the Android system back gesture / hardware back button.
/// Returns `false` when the framework leaves the pop to the OS (app exit).
Future<bool> _systemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await _settle(tester);
  return handled;
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('back on a secondary tab returns to Home, not exit',
      (tester) async {
    await _boot(tester);
    _router.go('/profile');
    await _settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    final handled = await _systemBack(tester);

    expect(handled, isTrue, reason: 'back must be consumed, not exit the app');
    expect(find.byType(HomeScreen), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('back on the servers tab returns to Home', (tester) async {
    await _boot(tester);
    _router.go('/servers');
    await _settle(tester);
    expect(find.byType(ServersScreen), findsOneWidget);

    await _systemBack(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('back on Home is left to the system (app exits)',
      (tester) async {
    await _boot(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    final handled = await _systemBack(tester);

    expect(handled, isFalse,
        reason: 'Home is the root branch — the OS handles the pop');
    await _dispose(tester);
  });

  testWidgets('pushed routes pop one step at a time: C -> B -> A',
      (tester) async {
    await _boot(tester);
    _router.go('/profile');
    await _settle(tester);
    _router.push('/settings');
    await _settle(tester);
    _router.push('/about');
    await _settle(tester);
    expect(find.byType(AboutScreen), findsOneWidget);

    // C -> B
    await _systemBack(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(AboutScreen), findsNothing);

    // B -> A
    await _systemBack(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);

    // A -> Home branch
    await _systemBack(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await _dispose(tester);
  });
}
