import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/domain/repositories/key_storage.dart';
import 'package:nexa_vpn/l10n/app_localizations.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/providers/identity_providers.dart';
import 'package:nexa_vpn/screens/identity/identity_screen.dart';
import 'package:nexa_vpn/services/identity/device_identity.dart';

/// Хранилище в памяти: настоящий Keystore в тестах недоступен.
class _MemoryKeyStorage implements KeyStorage {
  _MemoryKeyStorage([Map<String, String>? seed]) {
    if (seed != null) _values.addAll(seed);
  }

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

Future<ProviderContainer> _container([_MemoryKeyStorage? storage]) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      keyStorageProvider.overrideWithValue(storage ?? _MemoryKeyStorage()),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _MemoryKeyStorage storage,
) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        keyStorageProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IdentityScreen(),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('идентификатор вместо регистрации', () {
    test('код создаётся при первом запуске и сохраняется', () async {
      final storage = _MemoryKeyStorage();
      final container = await _container(storage);
      addTearDown(container.dispose);

      final code = await container.read(identityProvider.future);

      expect(DeviceIdentity.isValid(code), isTrue);
      // Код обязан пережить перезапуск: иначе человек потеряет доступ,
      // просто закрыв приложение.
      expect(await storage.read('nexa_identity_code'), code);
    });

    test('при повторном запуске код тот же, а не новый', () async {
      final storage = _MemoryKeyStorage();

      final c1 = await _container(storage);
      final first = await c1.read(identityProvider.future);
      c1.dispose();

      final c2 = await _container(storage);
      final second = await c2.read(identityProvider.future);
      c2.dispose();

      expect(second, first);
    });

    test('мусор в хранилище заменяется корректным кодом', () async {
      final storage = _MemoryKeyStorage({'nexa_identity_code': 'сломано'});
      final container = await _container(storage);
      addTearDown(container.dispose);

      final code = await container.read(identityProvider.future);

      expect(DeviceIdentity.isValid(code), isTrue);
      expect(code, isNot('сломано'));
    });

    test('восстановление принимает верный код и отвергает неверный',
        () async {
      final storage = _MemoryKeyStorage();
      final container = await _container(storage);
      addTearDown(container.dispose);

      final original = await container.read(identityProvider.future);
      final notifier = container.read(identityProvider.notifier);

      // Негодный код НЕ должен затирать существующий: иначе человек,
      // ошибившись при вводе, потеряет и старый доступ.
      expect(await notifier.restore('NEXA-1234'), isFalse);
      expect(await storage.read('nexa_identity_code'), original);

      const other = 'NEXA-A3C4-D6E7-F9G3-H4J6';
      expect(await notifier.restore(other), isTrue);
      expect(await storage.read('nexa_identity_code'), other);
    });

    test('код активации подписки не принимается как идентификатор',
        () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container.read(identityProvider.future);
      final notifier = container.read(identityProvider.notifier);

      // 8-значный код стоит одну подписку, 16-значный — все покупки.
      expect(await notifier.restore('NEXA-MHJQ-3JWX'), isFalse);
    });
  });

  group('экран «Мой код»', () {
    testWidgets('показывает код и предупреждение о потере', (tester) async {
      await _pumpScreen(tester, _MemoryKeyStorage());

      expect(find.text('Мой код'), findsOneWidget);
      expect(find.textContaining('Сохраните код'), findsOneWidget);
      // Человек должен понимать: восстановить код невозможно.
      expect(find.textContaining('не сможем восстановить'), findsOneWidget);
      expect(find.text('Скопировать'), findsOneWidget);
    });

    testWidgets('на экране нет ни почты, ни пароля', (tester) async {
      await _pumpScreen(tester, _MemoryKeyStorage());

      for (final word in ['Email', 'E-mail', 'Почта', 'Пароль', 'Password']) {
        expect(find.textContaining(word), findsNothing,
            reason: 'найдено «$word» — регистрация вернулась');
      }
    });
  });
}
