import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/identity/device_identity.dart';
import '../services/identity/identity_store.dart';
import 'app_providers.dart';

/// Идентификатор владельца — заменяет собой регистрацию.
///
/// Логика простая: при первом запуске код создаётся на телефоне и
/// сохраняется. Дальше он просто читается. Наружу не уходит: сервер о нём
/// узнаёт, только если человек сам предъявит код.
///
/// Хранение — через [IdentityStore]: защищённое хранилище плюс копия в
/// обычных настройках. Если Keystore недоступен (частая беда после
/// переустановки сборки с другой подписью), приложение НЕ остаётся без кода.
final identityProvider =
    AsyncNotifierProvider<IdentityNotifier, String>(IdentityNotifier.new);

class IdentityNotifier extends AsyncNotifier<String> {
  IdentityStore get _store => ref.read(identityStoreProvider);

  @override
  Future<String> build() async {
    final code = await _store.resolve();
    ref.read(loggerProvider).info(
          'Код владельца готов (${DeviceIdentity.isValid(code) ? "формат верный" : "ФОРМАТ НЕВЕРНЫЙ"})',
          source: 'identity',
        );
    return code;
  }

  /// Восстановление доступа на другом устройстве: человек вводит код,
  /// записанный при первой установке.
  ///
  /// Возвращает false, если код не проходит проверку формата — тогда UI
  /// обязан показать ошибку и НЕ перезаписывать существующий код.
  Future<bool> restore(String input) async {
    final normalised = DeviceIdentity.normalise(input);
    if (normalised.isEmpty) return false;

    await _store.save(normalised);
    state = AsyncData(normalised);
    ref.read(loggerProvider).info(
          'Код владельца восстановлен из ввода',
          source: 'identity',
        );
    return true;
  }

  /// Полный сброс: забыть код и завести новый.
  ///
  /// Нужен, когда телефон передают другому человеку. Прежний код после
  /// этого на устройстве не восстановить — предупредить об этом обязан UI.
  Future<void> reset() async {
    final fresh = await _store.reset();
    state = AsyncData(fresh);
  }
}
