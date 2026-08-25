import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/l10n/app_localizations.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/providers/consent_providers.dart';
import 'package:nexa_vpn/screens/consent/vpn_consent_screen.dart';

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
  addTearDown(container.dispose);

  // A real router: accepting navigates home.
  final router = GoRouter(
    initialLocation: '/consent',
    routes: [
      GoRoute(
        path: '/consent',
        builder: (_, __) => const VpnConsentScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-screen')),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) => const Scaffold(body: Text('privacy-screen')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  // AnimatedBackground loops forever, so pumpAndSettle would time out.
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  group('VpnService disclosure', () {
    testWidgets('states all four required facts about traffic handling',
        (tester) async {
      await _boot(tester);

      // Google Play requires the disclosure to explain what the app does
      // with user data — not just link to a policy.
      expect(find.text('It creates a VPN tunnel'), findsOneWidget);
      expect(find.text('Your traffic is encrypted'), findsOneWidget);
      expect(find.text('We keep no activity logs'), findsOneWidget);
      expect(find.text('Nothing is sold to advertisers'), findsOneWidget);
    });

    testWidgets('mentions VpnService explicitly', (tester) async {
      await _boot(tester);

      final body = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(body, contains('VpnService'));
    });

    testWidgets('acceptance requires an affirmative action', (tester) async {
      final container = await _boot(tester);

      // Merely showing the screen must not grant consent.
      expect(container.read(vpnConsentProvider), isFalse);

      await tester.tap(find.text('I understand and agree'));
      // accept() is async and the route transition needs a few frames;
      // pumpAndSettle is unusable here (looping background animation).
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(container.read(vpnConsentProvider), isTrue);
      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('declining does not grant consent', (tester) async {
      final container = await _boot(tester);

      await tester.tap(find.text('Not now'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(vpnConsentProvider), isFalse);
      expect(find.text('You need to accept this to use the VPN.'),
          findsOneWidget);
    });

    testWidgets('acceptance is persisted across launches', (tester) async {
      final container = await _boot(tester);
      await container.read(vpnConsentProvider.notifier).accept();
      await tester.pump(const Duration(milliseconds: 300));

      // Simulate a relaunch with the stored preference.
      final restarted = await _boot(
        tester,
        prefs: {'nexa_vpn_consent_accepted': true},
      );
      expect(restarted.read(vpnConsentProvider), isTrue);
    });

    testWidgets('renders in Russian too', (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      final instance = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VpnConsentScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Я понимаю и соглашаюсь'), findsOneWidget);
      expect(find.text('Мы не ведём журналы активности'), findsOneWidget);
    });
  });

  group('VpnConsentNotifier', () {
    test('defaults to false and survives revoke', () async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      final instance = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
      );
      addTearDown(container.dispose);

      expect(container.read(vpnConsentProvider), isFalse);

      await container.read(vpnConsentProvider.notifier).accept();
      expect(container.read(vpnConsentProvider), isTrue);

      await container.read(vpnConsentProvider.notifier).revoke();
      expect(container.read(vpnConsentProvider), isFalse);
    });
  });
}
