import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity_providers.dart';

/// Код владельца приложения.
///
/// Задаётся при сборке, в исходники не попадает:
///
///   flutter build apk --dart-define=OWNER_CODE=NEXA-XXXX-XXXX-XXXX-XXXX
///
/// Для debug-сборок (flutter run) используется значение по умолчанию.
const String kOwnerCode = String.fromEnvironment(
  'OWNER_CODE',
  defaultValue: 'NEXA-XMAE-7RPQ-C6CE-TYFW',
);

/// Открыт ли раздел выпуска ключей на этом устройстве.
///
/// Раньше проверялась роль в аккаунте. Аккаунтов больше нет, поэтому
/// признак владельца — совпадение кода устройства с кодом, заданным
/// при сборке. Ключ хранится в Android Keystore и наружу не уходит.
final adminUnlockedProvider = Provider<bool>((ref) {
  if (kOwnerCode.isEmpty) return false;

  final code = ref.watch(identityProvider).value;
  if (code == null) return false;

  return code == kOwnerCode;
});
