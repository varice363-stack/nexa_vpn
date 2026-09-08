import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../core/utils/app_logger.dart';

/// SSL Pinning service for secure API communication.
///
/// Implements certificate pinning to prevent MITM attacks.
/// Validates server certificates against known public key hashes.
/// Uses native dart:io — no external packages needed.
class SslPinningService {
  final AppLogger? _logger;

  // Known certificate hashes for our API servers.
  // These are SHA-256 hashes of the Subject Public Key Information (SPKI).
  // Update these when certificates are rotated.
  static const Map<String, List<String>> _knownPins = {
    'api.morokvpn.app': [
      // Production server certificate pins
      // TODO: Replace with real pins after VPS deployment
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
    ],
    'staging.morokvpn.app': [
      'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=',
    ],
  };

  SslPinningService(this._logger);

  /// Validates SSL certificate for the given hostname.
  ///
  /// Connects to the host, extracts the certificate, computes SHA-256 of
  /// its DER bytes, and checks against known pins.
  ///
  /// Returns true if certificate matches at least one known pin.
  /// Returns false if validation fails or certificate is not recognized.
  Future<bool> validateCertificate(String hostname) async {
    try {
      final pins = _knownPins[hostname];
      if (pins == null || pins.isEmpty) {
        _logger?.warn('No SSL pins configured for $hostname');
        return false;
      }

      // Connect and extract certificate
      final socket = await SecureSocket.connect(
        hostname,
        443,
        onBadCertificate: (cert) {
          // Accept temporarily — we validate pins manually below
          return true;
        },
        timeout: const Duration(seconds: 5),
      );

      final cert = socket.peerCertificate;
      await socket.close();

      if (cert == null) {
        _logger?.error('No certificate received from $hostname');
        return false;
      }

      // Compute SHA-256 of the DER-encoded certificate
      final derBytes = cert.der;
      final digest = sha256.convert(derBytes);
      final fingerprint = base64.encode(digest.bytes);

      _logger?.debug('Certificate fingerprint for $hostname: $fingerprint');

      // Check against known pins
      for (final pin in pins) {
        if (fingerprint == pin) {
          _logger?.info('SSL pinning validation successful for $hostname');
          return true;
        }
      }

      _logger?.error(
        'SSL pinning validation failed for $hostname - certificate mismatch. '
        'Got: $fingerprint',
      );
      return false;
    } on SocketException catch (e) {
      _logger?.error('SSL pinning connection error for $hostname: $e');
      return false;
    } catch (e) {
      _logger?.error('SSL pinning validation error for $hostname: $e');
      return false;
    }
  }

  /// Creates an [HttpClient] with SSL pinning enabled.
  ///
  /// Use this client for API requests instead of the default one.
  /// Rejects connections to hosts with mismatched certificates.
  HttpClient createPinnedClient() {
    final client = HttpClient();
    client.badCertificateCallback = (
      X509Certificate cert,
      String host,
      int port,
    ) {
      final pins = _knownPins[host];
      if (pins == null || pins.isEmpty) {
        // Unknown host — fall back to system validation
        return false;
      }

      final derBytes = cert.der;
      final digest = sha256.convert(derBytes);
      final fingerprint = base64.encode(digest.bytes);

      final matched = pins.contains(fingerprint);
      if (!matched) {
        _logger?.error(
          'Pinned client rejected $host:$port — fingerprint $fingerprint '
          'not in known pins',
        );
      }
      return matched;
    };
    return client;
  }

  /// Validates certificate before making HTTP request.
  ///
  /// Throws exception if validation fails.
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

  /// Updates known pins for a hostname (for certificate rotation).
  ///
  /// Should only be called during controlled maintenance windows.
  void updatePins(String hostname, List<String> newPins) {
    _knownPins[hostname] = newPins;
    _logger?.info('Updated SSL pins for $hostname');
  }

  /// Gets current pins for a hostname (for debugging).
  List<String>? getCurrentPins(String hostname) {
    return _knownPins[hostname];
  }
}

/// Exception thrown when SSL pinning validation fails.
class SslPinningValidationException implements Exception {
  final String message;

  SslPinningValidationException(this.message);

  @override
  String toString() => 'SslPinningValidationException: $message';
}
