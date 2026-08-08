import '../../domain/repositories/key_storage.dart';
import '../../core/utils/app_logger.dart';

/// Secure JWT storage.
///
/// Uses the platform secure storage ([KeyStorage] — Keychain/Keystore/DPAPI).
/// If the secure backend is unavailable (e.g. Linux desktop without
/// libsecret, widget tests), degrades to a non-persistent in-memory store
/// so the app keeps working; the token is then lost on restart.
class TokenStorage {
  TokenStorage({required KeyStorage storage, AppLogger? logger})
      : _storage = storage,
        _logger = logger;

  static const String tokenKey = 'nexa_auth_token';

  final KeyStorage _storage;
  final AppLogger? _logger;
  final Map<String, String> _memoryFallback = {};
  bool _secureUnavailable = false;

  Future<String?> read() async {
    if (_secureUnavailable) return _memoryFallback[tokenKey];
    try {
      return await _storage.read(tokenKey);
    } catch (e) {
      _secureUnavailable = true;
      _logger?.warn('Secure storage unavailable, using memory fallback: $e',
          source: 'api');
      return _memoryFallback[tokenKey];
    }
  }

  Future<void> write(String token) async {
    _memoryFallback[tokenKey] = token;
    if (_secureUnavailable) return;
    try {
      await _storage.write(tokenKey, token);
    } catch (e) {
      _secureUnavailable = true;
      _logger?.warn('Secure storage write failed, memory fallback only: $e',
          source: 'api');
    }
  }

  Future<void> clear() async {
    _memoryFallback.remove(tokenKey);
    if (_secureUnavailable) return;
    try {
      await _storage.delete(tokenKey);
    } catch (e) {
      _secureUnavailable = true;
      _logger?.warn('Secure storage delete failed: $e', source: 'api');
    }
  }
}
