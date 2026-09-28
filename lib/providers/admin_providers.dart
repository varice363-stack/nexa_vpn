import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/key_storage.dart';
import 'app_providers.dart';
import 'identity_providers.dart';

/// ЕДИНСТВЕННЫЙ СЕКРЕТНЫЙ КОД ВЛАДЕЛЬЦА ПРИЛОЖЕНИЯ.
const String kOwnerCode = String.fromEnvironment(
  'OWNER_CODE',
  defaultValue: 'MOROK-WJWY-4KCC-A7EC-JT9F',
);

const String _kAdminUnlockedKey = 'morok_admin_unlocked';

/// Асинхронный нотификатор состояния админки с постоянным сохранением.
final adminUnlockedNotifierProvider =
    AsyncNotifierProvider<AdminUnlockNotifier, bool>(AdminUnlockNotifier.new);

class AdminUnlockNotifier extends AsyncNotifier<bool> {
  KeyStorage get _storage => ref.read(keyStorageProvider);

  @override
  Future<bool> build() async {
    // 1. Проверяем сохраненный флаг разблокировки в Keystore
    final saved = await _storage.read(_kAdminUnlockedKey);
    if (saved == 'true') return true;

    // 2. Автоматическая разблокировка, если ID устройства совпадает с OWNER_CODE
    if (kOwnerCode.isNotEmpty) {
      final identityCode = ref.watch(identityProvider).value;
      if (identityCode != null) {
        final cleanIdentity =
            identityCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final cleanOwner = kOwnerCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (cleanIdentity == cleanOwner) {
          await _storage.write(_kAdminUnlockedKey, 'true');
          return true;
        }
      }
    }

    return false;
  }

  /// Попытка разблокировать админку по коду владельца и СОХРАНИТЬ навсегда.
  Future<bool> tryUnlock(String enteredCode) async {
    final cleanEntered =
        enteredCode.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    final cleanOwner =
        kOwnerCode.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    if (cleanEntered.isNotEmpty && cleanEntered == cleanOwner) {
      await _storage.write(_kAdminUnlockedKey, 'true');
      state = const AsyncData(true);
      return true;
    }
    return false;
  }

  /// Заблокировать / выйти из режима админа.
  Future<void> lock() async {
    await _storage.delete(_kAdminUnlockedKey);
    state = const AsyncData(false);
  }
}

/// Синхронный провайдер булева значения для быстрого чтения в UI.
final adminUnlockedProvider = Provider<bool>((ref) {
  final asyncVal = ref.watch(adminUnlockedNotifierProvider);
  return asyncVal.value ?? false;
});
