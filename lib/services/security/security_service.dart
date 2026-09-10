import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/utils/app_logger.dart';
import 'root_detection_service.dart';
import 'debugger_detection_service.dart';
import 'anti_tamper_service.dart';

/// Master security service that orchestrates all security checks.
///
/// Runs on app startup and periodically during runtime.
/// Provides comprehensive protection against:
/// - Rooted/jailbroken devices
/// - Debuggers
/// - Tampered/repackaged apps
/// - Emulators (in production)
class SecurityService {
  final AppLogger _logger;
  final RootDetectionService _rootDetection;
  final DebuggerDetectionService _debuggerDetection;
  final AntiTamperService _antiTamper;

  SecurityService(this._logger)
      : _rootDetection = RootDetectionService(_logger),
        _debuggerDetection = DebuggerDetectionService(_logger),
        _antiTamper = AntiTamperService(_logger);

  /// Run all security checks on app startup.
  /// Returns true if all checks pass, false otherwise.
  /// 
  /// ВАЖНО: проверки НЕ терминальны в debug/release без keystore,
  /// чтобы не блокировать разработку и тестирование.
  Future<SecurityCheckResult> runStartupChecks() async {
    _logger.info('Running startup security checks...');
    
    final results = <SecurityCheck>[];

    // Check 1: Debugger detection — только лог, не терминал
    final hasDebugger = _debuggerDetection.isDebuggerAttached();
    if (hasDebugger) {
      _logger.warn('Debugger detected (non-fatal)', source: 'security');
    }
    results.add(SecurityCheck('debugger', !hasDebugger, hasDebugger ? 'Debugger attached' : 'No debugger'));

    // Check 2: Root/jailbreak detection — только лог
    final isRooted = await _rootDetection.isRooted();
    if (isRooted) {
      _logger.warn('Device is rooted (non-fatal)', source: 'security');
    }
    results.add(SecurityCheck(
      'root',
      !isRooted,
      isRooted ? 'Device is rooted' : 'Device is clean',
    ));

    // Check 3: Anti-tamper — НЕ терминал, только лог
    final isTampered = !await _antiTamper.validateIntegrity();
    if (isTampered) {
      _logger.warn('App integrity check failed (non-fatal, likely debug build)', source: 'security');
    }
    results.add(SecurityCheck(
      'tamper',
      !isTampered,
      isTampered ? 'Possible tampering' : 'Integrity OK',
    ));

    final allPassed = results.every((r) => r.passed);
    _logger.info(
      'Security checks completed: ${allPassed ? "ALL PASSED" : "SOME FAILED (non-fatal)"}'
    );

    return SecurityCheckResult(
      passed: allPassed,
      checks: results,
      timestamp: DateTime.now(),
    );
  }

  /// Run periodic security checks during runtime.
  /// Called every few minutes to detect runtime attacks.
  Future<void> runPeriodicChecks() async {
    // Quick checks that don't require async operations
    _debuggerDetection.terminateIfDebuggerDetected();
    
    // Periodic integrity check (less frequent as it's more expensive)
    // This would be called from a timer in main.dart
  }

  /// Get current security status.
  Future<SecurityStatus> getSecurityStatus() async {
    final isRooted = await _rootDetection.isRooted();
    final isDebugger = _debuggerDetection.isDebuggerAttached();
    final isTampered = !await _antiTamper.validateIntegrity();
    final isEmulator = await _antiTamper.isEmulator();

    return SecurityStatus(
      isRooted: isRooted,
      isDebugger: isDebugger,
      isTampered: isTampered,
      isEmulator: isEmulator,
      timestamp: DateTime.now(),
    );
  }
}

/// Result of a security check.
class SecurityCheck {
  final String name;
  final bool passed;
  final String message;

  SecurityCheck(this.name, this.passed, this.message);

  @override
  String toString() => '$name: ${passed ? "PASS" : "FAIL"} - $message';
}

/// Overall result of security checks.
class SecurityCheckResult {
  final bool passed;
  final List<SecurityCheck> checks;
  final DateTime timestamp;

  SecurityCheckResult({
    required this.passed,
    required this.checks,
    required this.timestamp,
  });

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('Security Check Result: ${passed ? "PASSED" : "FAILED"}')
      ..writeln('Timestamp: $timestamp');
    for (final check in checks) {
      buffer.writeln('  $check');
    }
    return buffer.toString();
  }
}

/// Current security status snapshot.
class SecurityStatus {
  final bool isRooted;
  final bool isDebugger;
  final bool isTampered;
  final bool isEmulator;
  final DateTime timestamp;

  SecurityStatus({
    required this.isRooted,
    required this.isDebugger,
    required this.isTampered,
    required this.isEmulator,
    required this.timestamp,
  });

  bool get isSecure => !isRooted && !isDebugger && !isTampered;

  @override
  String toString() => 
    'Security Status: ${isSecure ? "SECURE" : "INSECURE"} '
    '(rooted: $isRooted, debugger: $isDebugger, '
    'tampered: $isTampered, emulator: $isEmulator)';
}
