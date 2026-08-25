import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexa_vpn/l10n/app_localizations.dart';
import 'package:nexa_vpn/providers/locale_providers.dart';

/// Pumps [child] under a given locale so widget text can be asserted.
Future<AppLocalizations> _localizationsFor(
  WidgetTester tester,
  Locale locale,
) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return l10n;
}

Map<String, dynamic> _arb(String name) {
  final file = File('lib/l10n/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('ARB catalogues', () {
    test('RU and EN define exactly the same keys', () {
      // Keys starting with @ are metadata, not translatable strings.
      Set<String> keysOf(Map<String, dynamic> m) =>
          m.keys.where((k) => !k.startsWith('@')).toSet();

      final en = keysOf(_arb('app_en.arb'));
      final ru = keysOf(_arb('app_ru.arb'));

      expect(
        ru.difference(en),
        isEmpty,
        reason: 'RU has keys missing from the EN template',
      );
      expect(
        en.difference(ru),
        isEmpty,
        reason: 'these keys are not translated into RU',
      );
      expect(en.length, greaterThan(180));
    });

    test('no RU value is left as untranslated English', () {
      final en = _arb('app_en.arb');
      final ru = _arb('app_ru.arb');

      // Brand names and a few tokens are intentionally identical.
      // Brand names and product tiers stay identical in both languages.
      const allowedIdentical = {
        'appName',
        'settingsDns',
        'serversFilterPremium',
        'settingsLanguageEnglish',
        'settingsLanguageRussian',
        'commonPremium',
        'premiumTitle',
        'profileNexaPremium',
        'supportTelegram',
      };

      final untranslated = <String>[];
      for (final key in en.keys.where((k) => !k.startsWith('@'))) {
        if (allowedIdentical.contains(key)) continue;
        if (en[key] == ru[key]) untranslated.add(key);
      }

      expect(untranslated, isEmpty,
          reason: 'RU still equals EN for: $untranslated');
    });
  });

  group('Locale resolution', () {
    testWidgets('English locale resolves English strings', (tester) async {
      final l10n = await _localizationsFor(tester, const Locale('en'));
      expect(l10n.navHome, 'Home');
      expect(l10n.loginWelcome, 'Welcome back');
    });

    testWidgets('Russian locale resolves Russian strings', (tester) async {
      final l10n = await _localizationsFor(tester, const Locale('ru'));
      expect(l10n.navHome, 'Главная');
      expect(l10n.loginWelcome, 'С возвращением');
    });

    testWidgets('placeholders survive translation', (tester) async {
      final ru = await _localizationsFor(tester, const Locale('ru'));
      expect(ru.powerConnectedFor('01:23'), contains('01:23'));

      final en = await _localizationsFor(tester, const Locale('en'));
      expect(en.powerConnectedFor('01:23'), contains('01:23'));
    });

    testWidgets('an unsupported locale falls back to English', (tester) async {
      final l10n = await _localizationsFor(tester, const Locale('fr'));
      expect(l10n.navHome, 'Home');
    });
  });

  group('AppLocale', () {
    test('system maps to a null Locale so Flutter follows the device', () {
      expect(AppLocale.system.toLocale, isNull);
      expect(AppLocale.en.toLocale, const Locale('en'));
      expect(AppLocale.ru.toLocale, const Locale('ru'));
    });

    test('unknown stored values degrade to system', () {
      expect(AppLocale.fromStorage(null), AppLocale.system);
      expect(AppLocale.fromStorage('de'), AppLocale.system);
      expect(AppLocale.fromStorage('ru'), AppLocale.ru);
      expect(AppLocale.fromStorage('en'), AppLocale.en);
    });
  });
}
