import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_logger.dart';
import '../data/datasources/local_settings_datasource.dart';
import '../data/repositories/config_repository_impl.dart';
import '../data/repositories/key_storage_impl.dart';
import '../data/repositories/server_repository_impl.dart';
import '../data/repositories/session_manager_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/access_repository.dart';
import '../domain/repositories/banner_repository.dart';
import '../domain/repositories/billing_repository.dart';
import '../domain/repositories/config_repository.dart';
import '../domain/repositories/key_storage.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/server_repository.dart';
import '../domain/repositories/session_manager.dart';
import '../domain/repositories/subscription_repository.dart';
import '../repositories/access_repository_impl.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/banner_repository_impl.dart';
import '../repositories/billing_repository_impl.dart';
import '../repositories/notification_repository_impl.dart';
import '../repositories/server_repository_impl.dart';
import '../repositories/subscription_repository_impl.dart';
import '../services/api/api_client.dart';
import '../services/api/token_storage.dart';
import '../services/notification_service.dart';

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

/// HTTP client for the Nexa VPN backend.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    logger: ref.watch(loggerProvider),
  ),
);

// ── Repositories ──────────────────────────────────────────────────────────

/// Authentication (login / register / me).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Access keys (the platform's core product).
final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => AccessRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Billing (plans, checkout, transactions).
final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Server catalog: backend API with local static fallback.
final serverRepositoryProvider = Provider<ServerRepository>(
  (ref) => ApiServerRepository(
    api: ref.watch(apiClientProvider),
    fallback: ServerRepositoryImpl(),
    logger: ref.watch(loggerProvider),
  ),
);

/// Promotional banners.
final bannerRepositoryProvider = Provider<BannerRepository>(
  (ref) => BannerRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// In-app notifications.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Subscriptions.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepositoryImpl(api: ref.watch(apiClientProvider)),
);

/// Session history.
final sessionManagerProvider = Provider<SessionManager>(
  (ref) => SessionManagerImpl(ref.watch(localSettingsProvider)),
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
