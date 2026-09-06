import 'dart:io';
import 'package:flutter_ssl_pinning/flutter_ssl_pinning.dart';
import '../core/utils/app_logger.dart';

/// SSL Pinning service for secure API communication.
///
/// Implements certificate pinning to prevent MITM attacks.
/// Validates server certificates against known public key hashes.
class SslPinningService {
  final AppLogger _logger;
  
  // Known certificate hashes for our API servers
  // These are SHA-256 hashes of the Subject Public Key Information (SPKI)
  static const Map<String, List<String>> _knownPins = {
    'api.nexavpn.app': [
      // Production server certificate pins
      // Update these when certificates are rotated
      'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Primary
      'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Backup
    ],
    'staging.nexavpn.app': [
      // Staging server certificate pins
      'sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=',
    ],
  };

  SslPinningService(this._logger);

  /// Validates SSL certificate for the given hostname.
  ///
  /// Returns true if certificate is valid and matches known pins.
  /// Returns false if validation fails or certificate is not recognized.
  Future<bool> validateCertificate(String hostname) async {
    try {
      final pins = _knownPins[hostname];
      if (pins == null || pins.isEmpty) {
        _logger.warning('No SSL pins configured for $hostname');
        return false;
      }

      final SslPinning plugin = SslPinning();
      
      // Check certificate with all known pins
      for (final pin in pins) {
        try {
          final result = await plugin.check(
            urls: ['https://$hostname'],
            sha: SSLPinningSHA.SHA256,
            allowedSHADigests: [pin],
          );
          
          if (result == 'Connection OK') {
            _logger.info('SSL pinning validation successful for $hostname');
            return true;
          }
        } catch (e) {
          _logger.debug('Pin validation failed for $hostname with pin: $e');
          continue;
        }
      }

      _logger.error('SSL pinning validation failed for $hostname - certificate mismatch');
      return false;
    } catch (e) {
      _logger.error('SSL pinning validation error for $hostname: $e');
      return false;
    }
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
    _logger.info('Updated SSL pins for $hostname');
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
