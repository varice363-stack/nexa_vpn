import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexa_vpn/models/access_key.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/providers/access_providers.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/providers/connection_source_providers.dart';

/// Stage A of making the app usable on day one: a single notion of "what we
/// are connecting to", indifferent to whether the key is ours or the user's.
///
/// The product bet is that a stranger's key must work exactly as well as a
/// purchased one — so these tests deliberately assert the two origins are
/// treated identically wherever it matters.

const _foreignUri =
    'vless://11111111-2222-3333-4444-555555555555@foreign.example:443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=abc&sid=ff&type=tcp&flow=xtls-rprx-vision#Foreign%20Node';

const _ourUri =
    'vless://99999999-8888-7777-6666-555555555555@nexa.example:443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=xyz&sid=aa&type=tcp&flow=xtls-rprx-vision#Nexa';

AccessKey _key({
  String id = 'key-1',
  String name = 'Nexa Key',
  String status = 'ACTIVE',
  String? configUri = _ourUri,
  DateTime? expiresAt,
}) {
  return AccessKey(
    id: id,
    name: name,
    status: status,
    protocol: 'VLESS',
    configUri: configUri,
    expiresAt: expiresAt,
  );
}

/// Container with a seeded prefs store; access keys are overridden per test
/// so nothing reaches the network.
Future<ProviderContainer> _container({
  List<AccessKey> keys = const [],
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(store),
      accessKeysProvider.overrideWith(() => _StubAccessKeys(keys)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

class _StubAccessKeys extends AccessKeysNotifier {
  _StubAccessKeys(this._keys);
  final List<AccessKey> _keys;

  @override
  Future<List<AccessKey>> build() async => _keys;
}

/// Prefs payload matching what ManualKeysNotifier persists.
String _importedStore(List<Map<String, Object?>> entries) =>
    jsonEncode(entries);

void main() {
  group('ConnectionSource — construction', () {
    test('maps a Nexa key with a config', () {
      final source = ConnectionSource.fromAccessKey(_key());
      expect(source, isNotNull);
      expect(source!.origin, ConnectionOrigin.nexa);
      expect(source.uri, _ourUri);
      expect(source.id, 'nexa:key-1');
      expect(source.isUsable, isTrue);
    });

    test('refuses a Nexa key with no config rather than offering a dead entry',
        () {
      expect(ConnectionSource.fromAccessKey(_key(configUri: null)), isNull);
      expect(ConnectionSource.fromAccessKey(_key(configUri: '')), isNull);
    });

    test('a revoked key is carried but marked unusable', () {
      final source = ConnectionSource.fromAccessKey(_key(status: 'REVOKED'));
      expect(source, isNotNull);
      expect(source!.isExpired, isTrue);
      expect(source.isUsable, isFalse);
    });

    test('maps an imported third-party link', () {
      final source = ConnectionSource.fromImported(
        uri: _foreignUri,
        label: 'Foreign Node',
      );
      expect(source.origin, ConnectionOrigin.imported);
      expect(source.host, 'foreign.example');
      expect(source.isUsable, isTrue);
    });

    test('an imported key is as usable as one of ours', () {
      final ours = ConnectionSource.fromAccessKey(_key())!;
      final theirs =
          ConnectionSource.fromImported(uri: _foreignUri, label: 'Foreign');

      // The core product promise: no downstream difference between origins.
      expect(ours.isUsable, theirs.isUsable);
      expect(ours.uri.startsWith('vless://'), isTrue);
      expect(theirs.uri.startsWith('vless://'), isTrue);
    });
  });

  group('connectionSourcesProvider — both origins in one list', () {
    test('is empty with nothing added', () async {
      final c = await _container();
      await c.read(accessKeysProvider.future);
      expect(c.read(connectionSourcesProvider), isEmpty);
      expect(c.read(hasConnectionSourceProvider), isFalse);
    });

    test('a user with only a foreign key can still connect', () async {
      final c = await _container(
        prefs: {
          'nexa_manual_keys': _importedStore([
            {
              'uri': _foreignUri,
              'label': 'Foreign Node',
              'addedAt': DateTime.now().toIso8601String(),
            },
          ]),
        },
      );
      await c.read(accessKeysProvider.future);

      final sources = c.read(connectionSourcesProvider);
      expect(sources, hasLength(1));
      expect(sources.single.origin, ConnectionOrigin.imported);
      // Day-one usefulness without ever buying from us.
      expect(c.read(hasConnectionSourceProvider), isTrue);
    });

    test('merges ours and theirs, ours first', () async {
      final c = await _container(
        keys: [_key()],
        prefs: {
          'nexa_manual_keys': _importedStore([
            {
              'uri': _foreignUri,
              'label': 'Foreign Node',
              'addedAt': DateTime.now().toIso8601String(),
            },
          ]),
        },
      );
      await c.read(accessKeysProvider.future);

      final sources = c.read(connectionSourcesProvider);
      expect(sources, hasLength(2));
      expect(sources[0].origin, ConnectionOrigin.nexa);
      expect(sources[1].origin, ConnectionOrigin.imported);
    });

    test('skips our keys that have no config', () async {
      final c = await _container(keys: [_key(configUri: null)]);
      await c.read(accessKeysProvider.future);
      expect(c.read(connectionSourcesProvider), isEmpty);
    });
  });

  group('activeSourceProvider — selection', () {
    test('defaults to the first usable source', () async {
      final c = await _container(keys: [_key()]);
      await c.read(accessKeysProvider.future);

      expect(c.read(activeSourceProvider)?.id, 'nexa:key-1');
    });

    test('skips an unusable source when falling back', () async {
      final c = await _container(
        keys: [_key(id: 'dead', status: 'REVOKED'), _key(id: 'live')],
      );
      await c.read(accessKeysProvider.future);

      expect(c.read(activeSourceProvider)?.id, 'nexa:live');
    });

    test('a stored choice survives a restart', () async {
      final imported = _importedStore([
        {
          'uri': _foreignUri,
          'label': 'Foreign Node',
          'addedAt': DateTime.now().toIso8601String(),
        },
      ]);

      final c = await _container(
        keys: [_key()],
        prefs: {'nexa_manual_keys': imported},
      );
      await c.read(accessKeysProvider.future);

      final foreign = c
          .read(connectionSourcesProvider)
          .firstWhere((s) => s.isImported);
      await c.read(activeSourceProvider.notifier).select(foreign);
      expect(c.read(activeSourceProvider)?.isImported, isTrue);

      // Same prefs, fresh container == app relaunch.
      final restarted = await _container(
        keys: [_key()],
        prefs: {
          'nexa_manual_keys': imported,
          'nexa_active_source': foreign.id,
        },
      );
      await restarted.read(accessKeysProvider.future);

      expect(restarted.read(activeSourceProvider)?.id, foreign.id);
      expect(restarted.read(activeSourceProvider)?.isImported, isTrue);
    });

    test('falls back when the stored choice has vanished', () async {
      // Points at an import that is no longer in the store.
      final c = await _container(
        keys: [_key()],
        prefs: {'nexa_active_source': 'imported:$_foreignUri'},
      );
      await c.read(accessKeysProvider.future);

      // Must not strand the user on a dead selection.
      expect(c.read(activeSourceProvider)?.id, 'nexa:key-1');
    });

    test('is null when there is nothing to connect to', () async {
      final c = await _container();
      await c.read(accessKeysProvider.future);
      expect(c.read(activeSourceProvider), isNull);
    });
  });
}
