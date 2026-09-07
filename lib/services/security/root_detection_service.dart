import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/utils/app_logger.dart';

/// Root/jailbreak detection service.
///
/// Checks if device is rooted (Android) or jailbroken (iOS).
/// Rooted devices pose security risks as they can bypass app sandboxing.
class RootDetectionService {
  final AppLogger _logger;
  static const _channel = MethodChannel('com.morokvpn.security');

  RootDetectionService(this._logger);

  /// Check if device is rooted/jailbroken.
  Future<bool> isRooted() async {
    if (kIsWeb) return false;
    
    try {
      // Platform-specific detection
      if (Platform.isAndroid) {
        return await _checkAndroidRoot();
      } else if (Platform.isIOS) {
        return await _checkIOSJailbreak();
      }
      return false;
    } catch (e) {
      _logger.error('Root detection failed', error: e);
      // Fail open - don't block legitimate users
      return false;
    }
  }

  Future<bool> _checkAndroidRoot() async {
    try {
      final bool? isRooted = await _channel.invokeMethod('isRooted');
      return isRooted ?? false;
    } on PlatformException catch (e) {
      _logger.warn('Android root detection failed', error: e);
      return _checkAndroidRootFallback();
    }
  }

  Future<bool> _checkAndroidRootFallback() {
    // Fallback checks for common root indicators
    final rootFiles = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/xbin/su',
    ];

    for (final file in rootFiles) {
      if (File(file).existsSync()) {
        _logger.warn('Root indicator found: $file');
        return Future.value(true);
      }
    }
    return Future.value(false);
  }

  Future<bool> _checkIOSJailbreak() async {
    try {
      final bool? isJailbroken = await _channel.invokeMethod('isJailbroken');
      return isJailbroken ?? false;
    } on PlatformException catch (e) {
      _logger.warn('iOS jailbreak detection failed', error: e);
      return _checkIOSJailbreakFallback();
    }
  }

  Future<bool> _checkIOSJailbreakFallback() {
    // Check for common jailbreak indicators
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
    ];

    for (final path in jailbreakPaths) {
      if (File(path).existsSync()) {
        _logger.warn('Jailbreak indicator found: $path');
        return Future.value(true);
      }
    }
    return Future.value(false);
  }

  /// Show warning dialog if device is rooted.
  Future<void> showRootWarning() async {
    _logger.warn('Device is rooted/jailbroken - security risk!');
    // UI will handle showing the warning dialog
  }
}
