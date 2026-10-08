import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morok_vpn/domain/repositories/key_storage.dart';
import 'package:morok_vpn/services/identity/device_identity.dart';
import 'package:morok_vpn/services/identity/identity_store.dart';

/// KeyStorage, который ведёт себя как испорченный Keystore: любое обращение
/// падает исключением. Ровно так выглядит телефон после установки сборки,
/// подписанной другим ключом, — и именно из-за этого приложение раньше молча
/// оставалось гостем: код владельца прочитать не удавалось, регистрация
/// отменялась, человеку ничего не сообщалось.
class _BrokenKeyStorage implements KeyStorage {
  @override
  Future<void> write(String key, String value) async =>
      throw Exception('Keystore недоступен');
  @override
  Future<String?> read(String key) async =>
      throw Exception('Keystore недоступен');
  @override
  Future<void> delete(String key) async =>
      throw Exception('Keystore недоступен');
  @override
  Future<bool> has(String key) async =>
      throw Exception('Keystore недоступен');
}

class _MemoryKeyStorage implements KeyStorage {
  _MemoryKeyStorage([Map<String, String>? seed]) : rows = {...?seed};
  final Map<String, String> rows;
  @override
  Future<void> write(String key, String value) async => rows[key] = value;
  @override
  Future<String?> read(String key) async => rows[key];
  @override
  Future<void> delete(String key) async => rows.remove(key);
  @override
  Future<bool> has(String key) async => rows.containsKey(key);
}

void main() {
  const validCode = 'MOROK-AAAA-BBBB-CCCC-DDDD';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('IdentityStore', () {
    test('исправное хранилище: отдаёт сохранённый код и дублирует копию',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(
        storage: _MemoryKeyStorage({IdentityStore.secureKey: validCode}),
        prefs: prefs,
      );

      expect(await store.resolve(), validCode);
      expect(prefs.getString(IdentityStore.fallbackKey), validCode);
    });

    test('сломанный Keystore: берёт копию из настроек, а не падает', () async {
      SharedPreferences.setMockInitialValues(
          {IdentityStore.fallbackKey: validCode});
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(storage: _BrokenKeyStorage(), prefs: prefs);

      expect(await store.resolve(), validCode);
    });

    test('сломанный Keystore и пустые настройки: заводит новый код', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(storage: _BrokenKeyStorage(), prefs: prefs);

      final code = await store.resolve();

      expect(DeviceIdentity.isValid(code), isTrue);
      expect(prefs.getString(IdentityStore.fallbackKey), code);
    });

    test('сломанная запись в Keystore не мешает сохранить код', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(storage: _BrokenKeyStorage(), prefs: prefs);

      await store.save(validCode);

      expect(prefs.getString(IdentityStore.fallbackKey), validCode);
      expect(await store.resolve(), validCode);
    });

    test('на «диске» лежал мусор: код пересоздаётся', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(
        storage: _MemoryKeyStorage({IdentityStore.secureKey: 'ерунда'}),
        prefs: prefs,
      );

      expect(DeviceIdentity.isValid(await store.resolve()), isTrue);
    });

    test('сброс заводит другой код', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = IdentityStore(
        storage: _MemoryKeyStorage({IdentityStore.secureKey: validCode}),
        prefs: prefs,
      );

      final fresh = await store.reset();

      expect(fresh, isNot(validCode));
      expect(DeviceIdentity.isValid(fresh), isTrue);
    });
  });
}
