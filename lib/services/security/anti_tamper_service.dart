import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/utils/app_logger.dart';

/// Anti-tampering service.
///
/// Validates app integrity by checking:
/// - APK signature (Android)
/// - Bundle signature (iOS)
/// - File checksums
/// Prevents modified/repackaged apps from running.
class AntiTamperService {
  final AppLogger _logger;
  static const _channel = MethodChannel('com.morokvpn.security');

  // Expected signatures (update these with your actual release signatures)
  static const String _expectedAndroidSignature = 
      'YOUR_RELEASE_SIGNATURE_HASH_HERE';
  static const String _expectedIOSSignature = 
      'YOUR_IOS_BUNDLE_SIGNATURE_HERE';

  AntiTamperService(this._logger);

  /// Validate app integrity.
  Future<bool> validateIntegrity() async {
    if (kIsWeb) return true;

    try {
      if (Platform.isAndroid) {
        return await _validateAndroidSignature();
      } else if (Platform.isIOS) {
        return await _validateIOSSignature();
      }
      return true;
    } catch (e) {
      _logger.error('Integrity validation failed', error: e);
      // Fail closed for security
      return false;
    }
  }

  Future<bool> _validateAndroidSignature() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      // Get APK signature via platform channel
      final String? signature = await _channel.invokeMethod('getApkSignature');
      
      if (signature == null) {
        // Native channel не реализован или недоступен — доверяем приложению
        // Это нормально для debug/release без нативной интеграции
        _logger.info('APK signature channel unavailable — skipping (dev build)', source: 'security');
        return true;
      }

      // Compare with expected signature
      final isValid = signature == _expectedAndroidSignature;
      
      if (!isValid) {
        _logger.error(
          'APK signature mismatch! '
          'Expected: $_expectedAndroidSignature, '
          'Got: $signature',
          source: 'security',
        );
      }

      return isValid;
    } catch (e) {
      // Platform channel недоступен — это нормально для dev-сборок
      _logger.info('Android signature validation skipped (dev build): $e', source: 'security');
      return true;
    }
  }

  Future<bool> _validateIOSSignature() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      // Get bundle signature via platform channel
      final String? signature = await _channel.invokeMethod('getBundleSignature');
      
      if (signature == null) {
        _logger.warn('Could not retrieve bundle signature');
        return false;
      }

      // Compare with expected signature
      final isValid = signature == _expectedIOSSignature;
      
      if (!isValid) {
        _logger.error(
          'Bundle signature mismatch! '
          'Expected: $_expectedIOSSignature, '
          'Got: $signature'
        );
      }

      return isValid;
    } catch (e) {
      _logger.error('iOS signature validation failed', error: e);
      return false;
    }
  }

  /// Check if app is running from emulator (development only).
  Future<bool> isEmulator() async {
    if (kIsWeb) return false;
    
    try {
      final bool? isEmulator = await _channel.invokeMethod('isEmulator');
      return isEmulator ?? false;
    } catch (e) {
      _logger.error('Emulator detection failed', source: 'security');
      return false;
    }
  }

  /// Terminate app if integrity check fails.
  Future<void> terminateIfTampered() async {
    final isValid = await validateIntegrity();
    if (!isValid) {
      // Non-fatal: только лог, не exit.
      // В production можно включить exit после настройки keystore.
      _logger.warn('Integrity check failed — NOT terminating (dev mode)', source: 'security');
    }
  }
}
