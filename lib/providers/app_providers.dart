import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api/api_config.dart';
import '../core/utils/app_logger.dart';
import '../data/datasources/local_settings_datasource.dart';
import '../data/repositories/config_repository_impl.dart';
import '../data/repositories/key_storage_impl.dart';
import '../data/repositories/session_manager_impl.dart';
import '../domain/repositories/admin_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/access_repository.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/banner_repository.dart';
import '../domain/repositories/config_repository.dart';
import '../domain/repositories/key_storage.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/server_repository.dart';
import '../domain/repositories/session_manager.dart';
import '../domain/repositories/subscription_repository.dart';
import '../repositories/access_repository_impl.dart';
import '../repositories/admin_repository_impl.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/account_repository_impl.dart';
import '../repositories/banner_repository_impl.dart';
import '../repositories/notification_repository_impl.dart';
import '../repositories/server_repository_impl.dart';
import '../repositories/subscription_repository_impl.dart';
import '../services/api/api_client.dart';
import '../services/api/token_storage.dart';
import '../services/identity/device_fingerprint.dart';
import '../services/identity/identity_store.dart';
import '../services/notification_service.dart';
import '../services/security/ssl_pinning_service.dart';
import '../services/security/security_service.dart';

/// Injected in `main()` via ProviderScope override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// Raw key-value persistence.
final localSettingsProvider = Provider<LocalSettingsDatasource>(
  (ref) => LocalSettingsDatasource(ref.watch(sharedPreferencesProvider)),
);

/// Application configuration (settings, favorites, subscription, profile).
final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepositoryImpl(ref.watch(localSettingsProvider)),
);

/// Secure storage for secrets.
final keyStorageProvider = Provider<KeyStorage>(
  (ref) => KeyStorageImpl(),
);

/// Secure JWT storage on top of [keyStorageProvider].
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(
    storage: ref.watch(keyStorageProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// SSL pinning service for secure API communication.
final sslPinningServiceProvider = Provider<SslPinningService>(
  (ref) => SslPinningService(ref.watch(loggerProvider)),
);

/// Ключ стабильного id устройства в SharedPreferences (см. deviceIdProvider).
const kDeviceIdKey = 'morok_device_id';

/// Хранилище кода владельца с самовосстановлением: защищённое хранилище +
/// копия в обычных настройках. Единственный источник кода для регистрации,
/// перевыпуска токена и экрана восстановления.
final identityStoreProvider = Provider<IdentityStore>(
  (ref) => IdentityStore(
    storage: ref.watch(keyStorageProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// Ключ кода владельца в защищённом хранилище (Android Keystore).
///
/// Общий на всё приложение: и регистрация на сервере (bootstrap), и
/// перевыпуск токена, и восстановление доступа обязаны говорить об ОДНОМ
/// идентификаторе. Раньше их было два — в регистрацию уходил код из Keystore,
/// а перевыпуск токена спрашивал случайный id из обычных настроек, которого
/// сервер не знал вовсе.
const kIdentityKey = 'morok_identity_code';

/// HTTP client for the Morok VPN backend.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    logger: ref.watch(loggerProvider),
    sslPinningService: ref.watch(sslPinningServiceProvider),
  );
  // 401 → сначала одна попытка перевыпустить токен, а не выбрасывать
  // пользователя. /auth/auto-register делает это по device-id: сервер находит
  // аккаунт и отдаёт новый JWT. Экрана «войти по паролю» в приложении нет,
  // поэтому прежний путь «сессия истекла → выйдите и войдите снова» был тупиком:
  // админ-экраны на 8-й день жизни токена просто переставали что-либо писать.
  client.refreshToken = () async {
    // ВАЖНО: берём ТОТ ЖЕ код владельца, которым устройство регистрировалось
    // (защищённое хранилище), а не случайный id из обычных настроек. Раньше
    // это были два разных идентификатора: сервер знал один, а перевыпуск
    // токена спрашивал другой — то есть перевыпуск не мог сработать ни разу.
    final deviceId = await ref.read(identityStoreProvider).resolve();
    try {
      // Напрямую, без AuthRepository: он сам построен поверх apiClientProvider,
      // и из колбэка получил бы цикл провайдеров.
      final fingerprint = await DeviceFingerprint.get();
      final res = await http
          .post(
            Uri.parse('${ApiConfig.resolvedBaseUrl}/auth/auto-register'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': deviceId,
              'platform': 'android-refresh',
              if (fingerprint != null) 'fingerprint': fingerprint,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) return false;
      final token = (jsonDecode(res.body) as Map)['accessToken'] as String?;
      if (token == null || token.isEmpty) return false;
      await ref.read(tokenStorageProvider).write(token);
      return true;
    } catch (e) {
      ref.read(loggerProvider).warn('token refresh failed: $e', source: 'auth');
      return false;
    }
  };
  return client;
});

// ── Repositories ──────────────────────────────────────────────────────────

/// Authentication (login / register / me).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Access keys (the platform's core product).
final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => AccessRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Server list from the backend. No local stand-in: when the API is down the
/// error is shown as it is, instead of invented servers.
final serverRepositoryProvider = Provider<ServerRepository>(
  (ref) => ApiServerRepository(
    api: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// Account self-service (password change).
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Promotional banners.
final bannerRepositoryProvider = Provider<BannerRepository>(
  (ref) => BannerRepositoryImpl(
    api: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// In-app notifications.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Subscriptions.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Admin dashboard, analytics, banner stats.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Session history.
final sessionManagerProvider = Provider<SessionManager>(
  // Выдуманную историю подключений пишем только в отладочной сборке:
  // в релизе пользователь видит лишь реальные сессии.
  (ref) => SessionManagerImpl(
    ref.watch(localSettingsProvider),
    seedDemo: kDebugMode,
  ),
);

/// Ring-buffer logger.
final loggerProvider = Provider<AppLogger>(
  (ref) {
    final logger = AppLogger();
    ref.onDispose(logger.dispose);
    return logger;
  },
);

/// In-app notification feed (local events, merged with API in
/// `notificationProvider`).
final notificationServiceProvider = Provider<NotificationService>(
  (ref) {
    final service = NotificationService();
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Security service — создаётся лениво, не блокирует запуск.
final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(AppLogger());
});
