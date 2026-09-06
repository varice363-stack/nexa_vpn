import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_logger.dart';

/// Debugger detection service.
///
/// Detects if app is running under a debugger.
/// Debuggers can be used to reverse engineer and modify app behavior.
class DebuggerDetectionService {
  final AppLogger _logger;
  static const _channel = MethodChannel('com.nexavpn.security');

  DebuggerDetectionService(this._logger);

  /// Check if debugger is attached.
  bool isDebuggerAttached() {
    if (kIsWeb) return false;
    
    // Dart debugger detection
    if (Debugger.isDebuggerConnected) {
      _logger.error('Debugger detected (Dart)');
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

  /// Terminate app if debugger is detected.
  void terminateIfDebuggerDetected() {
    if (isDebuggerAttached()) {
      _logger.critical('Terminating app due to debugger detection');
      // Give logger time to write
      Future.delayed(const Duration(milliseconds: 100), () {
        exit(0);
      });
    }
  }
}
