import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/key_storage.dart';
import 'app_providers.dart';
import 'identity_providers.dart';

/// Код владельца. Значение по умолчанию — ПУСТО: без
/// `--dart-define=OWNER_CODE=...` сборка не имеет админ-входа вообще.
/// (Раньше здесь был вшит реальный код — любой, кто распаковал бы публичный
/// APK, получал админку. Не возвращать.)
const String kOwnerCode =
    String.fromEnvironment('OWNER_CODE', defaultValue: '');

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
        final cleanIdentity = identityCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final cleanOwner = kOwnerCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (cleanIdentity == cleanOwner) {
          await _storage.write(_kAdminUnlockedKey, 'true');
          return true;
        }
      }
    }

    return false;
  }

  // Почему здесь БОЛЬШЕ нет «логина администратора»:
  //
  // Метод _ensureAdminToken входил на проде под admin@morokvpn.app с паролем
  // admin1234 из исходников и клал полученный JWT в токен ПОЛЬЗОВАТЕЛЯ. Это
  // (а) мусорный доступ — пароль в репозитории, в публичной сборке он не
  // передаётся, а бэкенд его давно не принимает → запрос падал, ошибка
  // глоталась catch, и админ-экраны шли без токена; (б) портил сессию
  // владельца, подменяя его собственный токен. Администратором владелецская
  // сборка становится по заголовку X-Owner-Code (ApiClient), поэтому токен
  // для админ-вызовов не нужен вовсе.

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
      state = const AsyncData(true);
      return true;
    }
    return false;
  }

  /// Заблокировать / выйти из режима админа.
  ///
  /// Токен пользователя НЕ трогается: режим админа держится на заголовке
  /// X-Owner-Code, а чистить из-за этого пользовательскую сессию — значит
  /// «за блокировку админки» платить выходом из приложения.
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
