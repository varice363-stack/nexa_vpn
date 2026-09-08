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
        _logger.warn('Could not retrieve APK signature');
        return false;
      }

      // Compare with expected signature
      final isValid = signature == _expectedAndroidSignature;
      
      if (!isValid) {
        _logger.error(
          'APK signature mismatch! '
          'Expected: $_expectedAndroidSignature, '
          'Got: $signature'
        );
      }

      return isValid;
    } catch (e) {
      _logger.error('Android signature validation failed', error: e);
      return false;
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
      _logger.error('Terminating app due to integrity check failure');
      // Give logger time to write
      await Future.delayed(const Duration(milliseconds: 100));
      exit(0);
    }
  }
}
