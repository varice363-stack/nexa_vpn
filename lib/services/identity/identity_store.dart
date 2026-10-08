import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/repositories/key_storage.dart';
import 'device_identity.dart';

/// Хранилище кода владельца (`MOROK-XXXX-XXXX-XXXX-XXXX`) с самовосстановлением.
///
/// Код — единственное, чем приложение опознаётся на сервере: без него нет ни
/// регистрации, ни пробного периода, ни ключей, ни статистики. Лежит он в
/// защищённом хранилище (Android Keystore / Keychain).
///
/// Проблема, из-за которой это появилось: защищённое хранилище не всегда
/// доступно. После установки сборки, подписанной другим ключом, после сбоя
/// провайдера или на кастомной прошивке чтение падает исключением. Раньше
/// исключение всплывало наружу, регистрация устройства молча отменялась — и
/// приложение НАВСЕГДА оставалось гостем, без единого сообщения человеку.
///
/// Теперь отказ хранилища работу не блокирует:
///  * код дублируется в обычные настройки (они доступны всегда);
///  * если защищённое чтение упало — берём копию оттуда;
///  * если и копии нет — заводим новый код и кладём в оба места.
///
/// Дублирование в обычные настройки — осознанный компромисс: код владельца
/// менее чувствителен, чем пароль (он не даёт доступа к деньгам напрямую), а
/// полная неработоспособность приложения из-за недоступного Keystore — хуже,
/// чем локальная копия, которую видно только на этом же телефоне.
class IdentityStore {
  IdentityStore({
    required KeyStorage storage,
    required SharedPreferences prefs,
    AppLogger? logger,
  })  : _storage = storage,
        _prefs = prefs,
        _logger = logger;

  /// Ключ кода в защищённом хранилище. Должен совпадать с историческим
  /// значением — иначе уже выданные коды «потеряются» при обновлении.
  static const String secureKey = 'morok_identity_code';

  /// Ключ копии в обычных настройках.
  static const String fallbackKey = 'morok_identity_code_copy';

  final KeyStorage _storage;
  final SharedPreferences _prefs;
  final AppLogger? _logger;

  bool _secureBroken = false;

  /// Возвращает действующий код, создавая его при необходимости.
  Future<String> resolve() async {
    // 1. Защищённое хранилище.
    if (!_secureBroken) {
      try {
        final secure = await _storage.read(secureKey);
        if (secure != null && DeviceIdentity.isValid(secure)) {
          final normalised = DeviceIdentity.normalise(secure);
          await _writeCopy(normalised);
          return normalised;
        }
      } catch (e) {
        _secureBroken = true;
        _logger?.warn(
          'Защищённое хранилище недоступно ($e) — беру копию кода',
          source: 'identity',
        );
      }
    }

    // 2. Копия в обычных настройках.
    final copy = _prefs.getString(fallbackKey);
    if (copy != null && DeviceIdentity.isValid(copy)) {
      final normalised = DeviceIdentity.normalise(copy);
      await _writeSecure(normalised);
      return normalised;
    }

    // 3. Совсем ничего — заводим новый код.
    final fresh = DeviceIdentity.generate();
    await save(fresh);
    _logger?.info(
      'Создан новый код владельца (защищённое хранилище ${_secureBroken ? "недоступно" : "пусто"})',
      source: 'identity',
    );
    return fresh;
  }

  /// Сохраняет код в оба места (защищённое — по возможности).
  Future<void> save(String code) async {
    final normalised = DeviceIdentity.normalise(code);
    if (normalised.isEmpty) return;
    await _writeSecure(normalised);
    await _writeCopy(normalised);
  }

  /// Забывает прежний код и заводит новый.
  Future<String> reset() async {
    final fresh = DeviceIdentity.generate();
    await save(fresh);
    _logger?.warn(
      'Код владельца сброшен — прежний восстановить нельзя',
      source: 'identity',
    );
    return fresh;
  }

  Future<void> _writeSecure(String code) async {
    if (_secureBroken) return;
    try {
      await _storage.write(secureKey, code);
    } catch (e) {
      _secureBroken = true;
      _logger?.warn(
        'Не удалось записать код в защищённое хранилище ($e) — '
        'остаётся копия в настройках',
        source: 'identity',
      );
    }
  }

  Future<void> _writeCopy(String code) async {
    try {
      await _prefs.setString(fallbackKey, code);
    } catch (e) {
      _logger?.warn('Не удалось записать копию кода ($e)', source: 'identity');
    }
  }
}
