import '../core/utils/app_logger.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/config_repository.dart';
import '../models/auth_user.dart';
import '../services/api/api_exception.dart';
import '../services/api/token_storage.dart';

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
///  * resolves the onboarding flag (first launch detection).
///
/// No artificial splash delay: navigation after bootstrap is driven by
/// the AuthGate redirect in the router.
class AppBootstrapService {
  AppBootstrapService({
    required TokenStorage tokenStorage,
    required ConfigRepository configRepository,
    required AuthRepository authRepository,
    required AppLogger logger,
  })  : _tokenStorage = tokenStorage,
        _configRepository = configRepository,
        _authRepository = authRepository,
        _logger = logger;

  final TokenStorage _tokenStorage;
  final ConfigRepository _configRepository;
  final AuthRepository _authRepository;
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
}
