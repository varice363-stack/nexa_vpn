import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/utils/app_logger.dart';

/// Debugger detection service.
///
/// Detects if app is running under a debugger.
/// Debuggers can be used to reverse engineer and modify app behavior.
class DebuggerDetectionService {
  final AppLogger _logger;
  static const _channel = MethodChannel('com.morokvpn.security');

  DebuggerDetectionService(this._logger);

  /// Check if debugger is attached.
  bool isDebuggerAttached() {
    if (kIsWeb) return false;
    
    // Flutter debug mode detection
    if (kDebugMode) {
      _logger.info('Debug mode detected');
      return true;
    }

    // Platform-specific debugger detection
    if (Platform.isAndroid || Platform.isIOS) {
      return _checkNativeDebugger();
    }

    return false;
  }

  bool _checkNativeDebugger() {
    try {
      // This would need native implementation
      // For now, return false as we can't easily detect native debuggers
      // without platform-specific code
      return false;
    } catch (e) {
      _logger.error('Native debugger detection failed', error: e);
      return false;
    }
  }

  /// Non-fatal debugger check — только лог в dev mode.
  void terminateIfDebuggerDetected() {
    if (isDebuggerAttached()) {
      _logger.warn('Debugger detected — not terminating (dev mode)', source: 'security');
    }
  }
}
