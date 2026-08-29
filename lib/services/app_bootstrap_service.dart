import '../core/utils/app_logger.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/config_repository.dart';
import '../domain/repositories/key_storage.dart';
import '../models/auth_user.dart';
import '../services/api/api_exception.dart';
import '../services/api/token_storage.dart';
import '../services/identity/device_identity.dart';

/// Ключ в защищённом хранилище устройства (Android Keystore).
const _kIdentityKey = 'nexa_identity_code';

/// Result of the application bootstrap sequence.
class BootstrapResult {
  const BootstrapResult({
    required this.onboardingCompleted,
    required this.hasToken,
    this.user,
  });

  final bool onboardingCompleted;
  final bool hasToken;
  final AuthUser? user;

  bool get isAuthenticated => user != null;
}

/// Startup sequence of the app.
///
/// Responsibilities:
///  * reads the stored token (secure storage);
///  * validates it against the backend (`GET /auth/me`) — auto login;
///  * **auto-registers the device** on first launch (`POST /auth/auto-register`)
///    so every user is visible in the admin dashboard even without an account;
///  * resolves the onboarding flag (first launch detection).
class AppBootstrapService {
  AppBootstrapService({
    required TokenStorage tokenStorage,
    required ConfigRepository configRepository,
    required AuthRepository authRepository,
    required KeyStorage keyStorage,
    required AppLogger logger,
  })  : _tokenStorage = tokenStorage,
        _configRepository = configRepository,
        _authRepository = authRepository,
        _keyStorage = keyStorage,
        _logger = logger;

  final TokenStorage _tokenStorage;
  final ConfigRepository _configRepository;
  final AuthRepository _authRepository;
  final KeyStorage _keyStorage;
  final AppLogger _logger;

  Future<BootstrapResult> run() async {
    _logger.info('Bootstrap started', source: 'bootstrap');

    final onboarding = await _configRepository.getOnboardingCompleted();

    String? token;
    try {
      token = await _tokenStorage.read();
    } catch (e) {
      _logger.warn('Token read failed: $e', source: 'bootstrap');
    }
    final hasToken = token != null && token.isNotEmpty;

    AuthUser? user;
    if (hasToken) {
      try {
        user = await _authRepository.me();
        _logger.info('Auto-login: ${user.email}', source: 'bootstrap');
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token expired/invalid — drop it, go guest.
          await _tokenStorage.clear();
          _logger.warn('Stored token invalid — cleared', source: 'bootstrap');
        } else {
          // Offline or server issue: keep the token, stay guest for now.
          _logger.warn('Auto-login skipped: $e', source: 'bootstrap');
        }
      } catch (e) {
        _logger.warn('Auto-login skipped: $e', source: 'bootstrap');
      }
    }

    // No authenticated user? Auto-register this device on the backend
    // so the admin dashboard can see it. Fire-and-forget — a failed
    // registration must never block the app from starting.
    if (user == null) {
      _autoRegisterIfPossible();
    }

    _logger.info(
      'Bootstrap done: onboarding=$onboarding authenticated=${user != null}',
      source: 'bootstrap',
    );
    return BootstrapResult(
      onboardingCompleted: onboarding,
      hasToken: hasToken,
      user: user,
    );
  }

  /// Silently registers this device on the backend.
  ///
  /// Reads the stored Device Identity (or creates one on first launch)
  /// and sends it to the backend. Errors are logged but swallowed: a missing
  /// backend or a network blip must not prevent the app from opening.
  /// The call retries on the next launch automatically.
  Future<void> _autoRegisterIfPossible() async {
    try {
      // Read existing Device Identity from secure storage (or create one).
      var deviceId = await _keyStorage.read(_kIdentityKey);
      if (deviceId == null || !DeviceIdentity.isValid(deviceId)) {
        deviceId = DeviceIdentity.generate();
        await _keyStorage.write(_kIdentityKey, deviceId);
        _logger.info('New Device Identity created: $deviceId', source: 'bootstrap');
      }

      _logger.info('Auto-registering device: $deviceId', source: 'bootstrap');

      final result = await _authRepository.autoRegister(deviceId: deviceId);
      await _tokenStorage.write(result.accessToken);

      _logger.info(
        'Auto-register success: user=${result.user.email}',
        source: 'bootstrap',
      );
    } on ApiException catch (e) {
      _logger.warn('Auto-register failed (network?): $e', source: 'bootstrap');
    } catch (e) {
      _logger.warn('Auto-register failed: $e', source: 'bootstrap');
    }
  }
}
