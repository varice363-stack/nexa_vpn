import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/key_storage.dart';
import 'app_providers.dart';
import 'identity_providers.dart';

/// Код владельца. Значение по умолчанию — ПУСТО: без
/// `--dart-define=OWNER_CODE=...` сборка не имеет админ-входа вообще.
/// (Раньше здесь был вшит реальный код — любой, кто распаковал бы публичный
/// APK, получал админку. Не возвращать.)
const String kOwnerCode = String.fromEnvironment('OWNER_CODE', defaultValue: '');

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
    if (saved == 'true') {
      await _ensureAdminToken();
      return true;
    }

    // 2. Автоматическая разблокировка, если ID устройства совпадает с OWNER_CODE
    if (kOwnerCode.isNotEmpty) {
      final identityCode = ref.watch(identityProvider).value;
      if (identityCode != null) {
        final cleanIdentity =
            identityCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final cleanOwner = kOwnerCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (cleanIdentity == cleanOwner) {
          await _storage.write(_kAdminUnlockedKey, 'true');
          await _ensureAdminToken();
          return true;
        }
      }
    }

    return false;
  }

  /// Получает JWT-токен админа для бекэнда при разблокировке.
  Future<void> _ensureAdminToken() async {
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null || token.isEmpty) {
        final result = await ref
            .read(authRepositoryProvider)
            .login('admin@morokvpn.app', 'admin1234');
        await ref.read(tokenStorageProvider).write(result.accessToken);
      }
    } catch (_) {
      // Игнорируем сетевые ошибки офлайн-режима
    }
  }

  /// Попытка разблокировать админку по коду владельца и СОХРАНИТЬ навсегда.
  Future<bool> tryUnlock(String enteredCode) async {
    final cleanEntered =
        enteredCode.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    final cleanOwner =
        kOwnerCode.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    // kOwnerCode пуст → сборка вообще не имеет админ-входа (публичные APK).
    if (kOwnerCode.isEmpty) return false;
    if (cleanEntered.isNotEmpty && cleanEntered == cleanOwner) {
      await _storage.write(_kAdminUnlockedKey, 'true');
      await _ensureAdminToken();
      state = const AsyncData(true);
      return true;
    }
    return false;
  }

  /// Заблокировать / выйти из режима админа.
  Future<void> lock() async {
    await _storage.delete(_kAdminUnlockedKey);
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(false);
  }
}

/// Синхронный провайдер булева значения для быстрого чтения в UI.
final adminUnlockedProvider = Provider<bool>((ref) {
  final asyncVal = ref.watch(adminUnlockedNotifierProvider);
  return asyncVal.value ?? false;
});
