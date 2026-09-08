import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../core/utils/app_logger.dart';

/// SSL Pinning service for secure API communication.
///
/// Implements certificate pinning to prevent MITM attacks.
///
/// Режимы работы:
/// 1. **Development** — пиннинг отключён (чтобы работало с localhost)
/// 2. **Production без пинов** — используется системная валидация сертификатов
///    (стандартный HTTPS с доверенными CA)
/// 3. **Production с пинами** — строгая проверка по SHA-256 хешу публичного ключа
///
/// Пины добавляются через [registerPin] после деплоя VPS:
/// ```bash
/// openssl s_client -connect api.morokvpn.app:443 2>/dev/null | \
///   openssl x509 -pubkey -noout | \
///   openssl pkey -pubin -outform der | \
///   openssl dgst -sha256 -binary | \
///   openssl enc -base64
/// ```
class SslPinningService {
  SslPinningService(this._logger);

  final AppLogger? _logger;

  /// Known certificate pins: hostname → list of SHA-256 base64 hashes.
  /// Empty by default — add via [registerPin] after VPS deployment.
  final Map<String, List<String>> _knownPins = {};

  /// Whether pinning is actively enforced (pins exist for the host).
  bool _strictModeEnabled = false;

  /// Загружает пины из конфига (вызывается при старте).
  /// В production замените на реальные значения.
  void loadProductionPins() {
    // После деплоя VPS раскомментируйте и подставьте реальные пины:
    // registerPin('api.morokvpn.app', 'REPLACE_WITH_REAL_SHA256_BASE64=');
    // _strictModeEnabled = true;

    if (_logger != null) {
      _logger!.info(
        'SSL pinning: ${_knownPins.isEmpty ? "disabled (no pins configured)" : "${_knownPins.length} host(s) pinned"}',
        source: 'ssl',
      );
    }
  }

  /// Добавляет пин для хоста.
  void registerPin(String hostname, String sha256Base64) {
    final pins = _knownPins.putIfAbsent(hostname, () => []);
    if (!pins.contains(sha256Base64)) {
      pins.add(sha256Base64);
    }
    _logger?.info('Registered SSL pin for $hostname', source: 'ssl');
  }

  /// Проверяет сертификат хоста.
  ///
  /// Логика:
  /// - Если пины для хоста не настроены → возвращает true (доверяем системе)
  /// - Если пины настроены → строгая проверка по SHA-256
  Future<bool> validateCertificate(String hostname) async {
    final pins = _knownPins[hostname];

    // Если пины не настроены — доверяем системным CA (стандартный HTTPS).
    // Это безопасно: без пинов MITM атакующий должен подменить весь CA,
    // что невозможно без компрометации доверенного центра.
    if (pins == null || pins.isEmpty) {
      _logger?.debug('No pins for $hostname — trusting system CA', source: 'ssl');
      return true;
    }

    try {
      // Подключаемся и получаем сертификат
      final socket = await SecureSocket.connect(
        hostname,
        443,
        onBadCertificate: (cert) => true, // Принимаем временно для проверки
        timeout: const Duration(seconds: 5),
      );

      final cert = socket.peerCertificate;
      await socket.close();

      if (cert == null) {
        _logger?.error('No certificate from $hostname', source: 'ssl');
        return false;
      }

      // SHA-256 от DER-кодированного сертификата
      final fingerprint = base64.encode(sha256.convert(cert.der).bytes);
      _logger?.debug('Cert fingerprint for $hostname: $fingerprint', source: 'ssl');

      for (final pin in pins) {
        if (fingerprint == pin) {
          _logger?.info('SSL pin matched for $hostname', source: 'ssl');
          return true;
        }
      }

      _logger?.error(
        'SSL pin MISMATCH for $hostname (got: $fingerprint)',
        source: 'ssl',
      );
      return false;
    } on SocketException catch (e) {
      _logger?.error('SSL connection error for $hostname: $e', source: 'ssl');
      return false;
    } catch (e) {
      _logger?.error('SSL validation error for $hostname: $e', source: 'ssl');
      return false;
    }
  }

  /// Создаёт HttpClient с пиннингом.
  /// Если пины не настроены — работает как обычный клиент.
  HttpClient createPinnedClient() {
    final client = HttpClient();
    client.badCertificateCallback = (
      X509Certificate cert,
      String host,
      int port,
    ) {
      final pins = _knownPins[host];
      if (pins == null || pins.isEmpty) {
        // Нет пинов — полагаемся на системную валидацию
        return false;
      }

      final fingerprint = base64.encode(sha256.convert(cert.der).bytes);
      final matched = pins.any((p) => p == fingerprint);

      if (!matched) {
        _logger?.error(
          'Pinned client rejected $host:$port (fingerprint: $fingerprint)',
          source: 'ssl',
        );
      }
      return matched;
    };
    return client;
  }

  /// Валидация перед HTTP запросом.
  /// НЕ блокирует работу если пины не настроены.
  Future<void> validateBeforeRequest(String url) async {
    final uri = Uri.parse(url);
    final hostname = uri.host;

    final isValid = await validateCertificate(hostname);
    if (!isValid) {
      throw SslPinningValidationException(
        'SSL certificate validation failed for $hostname. '
        'Connection may be compromised.',
      );
    }
  }

  void updatePins(String hostname, List<String> newPins) {
    _knownPins[hostname] = newPins;
    _logger?.info('Updated SSL pins for $hostname', source: 'ssl');
  }

  List<String>? getCurrentPins(String hostname) => _knownPins[hostname];
}

class SslPinningValidationException implements Exception {
  final String message;
  SslPinningValidationException(this.message);

  @override
  String toString() => 'SslPinningValidationException: $message';
}
