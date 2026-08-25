import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/key_storage.dart';
import '../services/identity/device_identity.dart';
import 'app_providers.dart';

/// Ключ в защищённом хранилище устройства (Android Keystore).
const _kIdentityKey = 'nexa_identity_code';

/// Идентификатор владельца — заменяет собой регистрацию.
///
/// Логика простая: при первом запуске код создаётся на телефоне и
/// сохраняется. Дальше он просто читается. Наружу не уходит: сервер о нём
/// узнаёт, только если человек сам предъявит код.
final identityProvider =
    AsyncNotifierProvider<IdentityNotifier, String>(IdentityNotifier.new);

class IdentityNotifier extends AsyncNotifier<String> {
  KeyStorage get _storage => ref.read(keyStorageProvider);

  @override
  Future<String> build() async {
    final existing = await _storage.read(_kIdentityKey);
    if (existing != null && DeviceIdentity.isValid(existing)) {
      return DeviceIdentity.normalise(existing);
    }

    // Первый запуск (или в хранилище лежал мусор) — заводим новый код.
    final fresh = DeviceIdentity.generate();
    await _storage.write(_kIdentityKey, fresh);
    ref.read(loggerProvider).info(
          'Device identity created',
          source: 'identity',
        );
    return fresh;
  }

  /// Восстановление доступа на другом устройстве: человек вводит код,
  /// записанный при первой установке.
  ///
  /// Возвращает false, если код не проходит проверку формата — тогда UI
  /// обязан показать ошибку и НЕ перезаписывать существующий код.
  Future<bool> restore(String input) async {
    final normalised = DeviceIdentity.normalise(input);
    if (normalised.isEmpty) return false;

    await _storage.write(_kIdentityKey, normalised);
    state = AsyncData(normalised);
    ref.read(loggerProvider).info(
          'Device identity restored from user input',
          source: 'identity',
        );
    return true;
  }

  /// Полный сброс: забыть код и завести новый.
  ///
  /// Нужен, когда телефон передают другому человеку. Прежний код после
  /// этого на устройстве не восстановить — предупредить об этом обязан UI.
  Future<void> reset() async {
    final fresh = DeviceIdentity.generate();
    await _storage.write(_kIdentityKey, fresh);
    state = AsyncData(fresh);
    ref.read(loggerProvider).warn(
          'Device identity reset — previous code is gone',
          source: 'identity',
        );
  }
}
