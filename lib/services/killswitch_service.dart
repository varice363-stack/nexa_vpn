import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils/app_logger.dart';

/// Native Kill Switch integration.
///
/// Uses platform channels to communicate with native Android code
/// that monitors VPN state and blocks traffic when VPN drops.
///
/// On Android 12+ (API 31+), uses VpnService.Builder.setBlocking(true).
/// On older versions, monitors VPN state via NetworkCallback and notifies Flutter.
class KillSwitchService {
  KillSwitchService({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;
  static const MethodChannel _channel =
      MethodChannel('com.nexavpn.killswitch');

  bool _isEnabled = false;
  bool _isSupported = false;
  bool _vpnDropped = false;
  VoidCallback? _onVpnDrop;

  /// Whether the current platform supports native Kill Switch.
  bool get isSupported => _isSupported;

  /// Whether Kill Switch is currently enabled.
  bool get isEnabled => _isEnabled;

  /// True when VPN dropped while Kill Switch was active.
  bool get vpnDropped => _vpnDropped;

  /// Callback when VPN drops unexpectedly.
  set onVpnDrop(VoidCallback? callback) => _onVpnDrop = callback;

  /// Initialize Kill Switch service.
  Future<void> initialize() async {
    try {
      _isSupported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      final androidVersion =
          await _channel.invokeMethod<int>('getAndroidVersion') ?? 0;

      _logger.info(
        'Kill Switch initialized: supported=$_isSupported, android=$androidVersion',
        source: 'killswitch',
      );

      // Set up method call handler for native callbacks
      _channel.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      _logger.error('Kill Switch init failed: $e', source: 'killswitch');
      _isSupported = false;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'vpnDropped':
        _logger.warn('VPN dropped! Kill Switch activated.', source: 'killswitch');
        _vpnDropped = true;
        _onVpnDrop?.call();
        break;
    }
    return null;
  }

  /// Enable Kill Switch.
  Future<void> enable() async {
    if (!_isSupported) {
      _logger.warn(
        'Kill Switch not supported on this platform. '
        'Enable "Always-on VPN" in Android settings instead.',
        source: 'killswitch',
      );
    }

    try {
      await _channel.invokeMethod('enable');
      _isEnabled = true;
      _vpnDropped = false;
      _logger.info('Kill Switch enabled', source: 'killswitch');
    } catch (e) {
      _logger.error('Failed to enable Kill Switch: $e', source: 'killswitch');
      rethrow;
    }
  }

  /// Disable Kill Switch.
  Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
      _isEnabled = false;
      _vpnDropped = false;
      _logger.info('Kill Switch disabled', source: 'killswitch');
    } catch (e) {
      _logger.error('Failed to disable Kill Switch: $e', source: 'killswitch');
    }
  }

  /// Reset the VPN dropped state after successful reconnect.
  void resetVpnDropped() {
    _vpnDropped = false;
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
