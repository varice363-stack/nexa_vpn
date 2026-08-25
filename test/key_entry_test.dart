import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/models/key_input.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/providers/manual_key_providers.dart';

const _vless =
    'vless://11111111-2222-3333-4444-555555555555@example.com:443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=abc&sid=ff&type=tcp&flow=xtls-rprx-vision#Berlin%20Node';

Future<ProviderContainer> _container() async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('KeyInput.parse — Nexa codes', () {
    test('recognises the canonical code', () {
      final input = KeyInput.parse('NEXA-7QK2-M4XP');
      expect(input.kind, KeyInputKind.nexaCode);
      expect(input.value, 'NEXA-7QK2-M4XP');
    });

    test('accepts sloppy real-world typing', () {
      for (final raw in [
        'nexa-7qk2-m4xp',
        '  NEXA7QK2M4XP  ',
        '7QK2-M4XP',
        '7qk2m4xp',
        'nexa 7qk2 m4xp',
      ]) {
        final input = KeyInput.parse(raw);
        expect(input.kind, KeyInputKind.nexaCode, reason: raw);
        expect(input.value, 'NEXA-7QK2-M4XP', reason: raw);
      }
    });

    test('rejects the wrong length rather than guessing', () {
      for (final raw in ['NEXA-7QK2', '7QK2', 'NEXA-7QK2-M4XP-99']) {
        expect(KeyInput.parse(raw).kind, KeyInputKind.unknown, reason: raw);
      }
    });
  });

  group('KeyInput.parse — third-party VLESS links', () {
    test('accepts a full vless:// link and reads its label', () {
      final input = KeyInput.parse(_vless);
      expect(input.kind, KeyInputKind.vlessUri);
      expect(input.label, 'Berlin Node');
    });

    test('accepts a link with no fragment', () {
      final input = KeyInput.parse(
        'vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443?type=tcp',
      );
      expect(input.kind, KeyInputKind.vlessUri);
      expect(input.label, isNull);
    });

    test('rejects a link missing the uuid or the host', () {
      expect(KeyInput.parse('vless://@example.com:443').kind,
          KeyInputKind.unknown);
      expect(KeyInput.parse('vless://uuid-only').kind, KeyInputKind.unknown);
    });

    test('rejects protocols the tunnel cannot speak', () {
      // Recognised only so the UI can say precisely why.
      for (final raw in [
        'vmess://abc',
        'trojan://pass@host:443',
        'ss://method:pass@host:8388',
      ]) {
        expect(KeyInput.parse(raw).kind, KeyInputKind.unknown, reason: raw);
      }
    });

    test('empty input is not valid', () {
      expect(KeyInput.parse('').isValid, isFalse);
      expect(KeyInput.parse('   ').isValid, isFalse);
    });
  });

  group('ManualKeys store', () {
    test('imports a third-party key and keeps its label', () async {
      final c = await _container();
      final notifier = c.read(manualKeysProvider.notifier);

      await notifier.add(KeyInput.parse(_vless));

      final keys = c.read(manualKeysProvider);
      expect(keys, hasLength(1));
      expect(keys.first.label, 'Berlin Node');
      expect(keys.first.host, 'example.com');
    });

    test('re-importing the same link does not duplicate it', () async {
      final c = await _container();
      final notifier = c.read(manualKeysProvider.notifier);

      await notifier.add(KeyInput.parse(_vless));
      await notifier.add(KeyInput.parse(_vless));

      expect(c.read(manualKeysProvider), hasLength(1));
    });

    test('refuses to store a Nexa code as a manual key', () async {
      final c = await _container();
      // Nexa codes belong on the server, not in the local store.
      await c.read(manualKeysProvider.notifier).add(
            KeyInput.parse('NEXA-7QK2-M4XP'),
          );
      expect(c.read(manualKeysProvider), isEmpty);
    });

    test('removes a key', () async {
      final c = await _container();
      final notifier = c.read(manualKeysProvider.notifier);
      await notifier.add(KeyInput.parse(_vless));

      await notifier.remove(_vless);
      expect(c.read(manualKeysProvider), isEmpty);
    });

    test('survives a restart', () async {
      final c = await _container();
      await c.read(manualKeysProvider.notifier).add(KeyInput.parse(_vless));

      // Same backing store, fresh container = relaunch.
      final prefs = await SharedPreferences.getInstance();
      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restarted.dispose);

      expect(restarted.read(manualKeysProvider), hasLength(1));
    });

    test('a corrupted store degrades to empty instead of crashing', () async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({
        'nexa_manual_keys': 'not-json-at-all',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      expect(c.read(manualKeysProvider), isEmpty);
    });
  });
}
