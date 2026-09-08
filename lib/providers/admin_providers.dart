import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity_providers.dart';

/// Код владельца приложения.
///
/// Задаётся при сборке, в исходники не попадает:
///
///   flutter build apk --dart-define=OWNER_CODE=NEXA-ADMIN-2026
///
/// Для debug-сборок (flutter run) используется значение по умолчанию.
const String kOwnerCode = String.fromEnvironment(
  'OWNER_CODE',
  defaultValue: 'NEXA-66AB-AV3H-9HSJ-R8VZ',
);

/// Открыт ли раздел выпуска ключей на этом устройстве.
///
/// Работает через ручной ввод кода владельца:
/// 1. Пользователь нажимает "Войти как админ" в профиле
/// 2. Вводит код OWNER_CODE (задаётся при сборке)
/// 3. Если код верный — админка разблокирована
///
/// Также автоматически разблокируется, если код устройства совпадает
/// с OWNER_CODE (для отладки через --dart-define).
final adminUnlockedProvider = Provider<bool>((ref) {
  // Проверяем ручную разблокировку через контроллер
  final controller = ref.watch(adminUnlockControllerProvider);
  if (controller.isUnlocked) return true;

  // Автоматическая разблокировка — для debug-сборок, где OWNER_CODE совпадает
  // с кодом устройства (удобно при разработке)
  if (kOwnerCode.isEmpty) return false;
  final code = ref.watch(identityProvider).value;
  if (code == null) return false;
  if (code == kOwnerCode) return true;

  return false;
});

/// Провайдер для управления состоянием админки (ввод кода).
final adminUnlockControllerProvider =
    Provider<AdminUnlockController>((ref) => AdminUnlockController());

class AdminUnlockController {
  bool _isUnlocked = false;

  /// Попытка разблокировать админку по коду владельца.
  /// Возвращает true если код верный.
  bool tryUnlock(String enteredCode) {
    final normalised = enteredCode.trim().toUpperCase();
    if (normalised == kOwnerCode) {
      _isUnlocked = true;
      return true;
    }
    return false;
  }

  /// Заблокировать админку.
  void lock() {
    _isUnlocked = false;
  }

  /// Текущее состояние.
  bool get isUnlocked => _isUnlocked;
}
