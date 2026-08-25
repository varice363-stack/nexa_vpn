import 'dart:async';

import 'package:flutter_vless/flutter_vless.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/services/tunnel_manager.dart';
import '../../models/connection_source.dart';
import '../../models/vpn_config.dart';
import '../../models/vpn_status.dart';

/// Production tunnel backed by Xray-core through `flutter_vless`.
///
/// This is what makes an imported key genuinely useful: the plugin parses any
/// `vless://` share link into an Xray config and dials it, so a key bought
/// elsewhere works the same as one of ours. No part of this class inspects
/// [ConnectionSource.origin].
class XrayTunnelManager implements TunnelManager {
  XrayTunnelManager({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  final StreamController<TunnelPhase> _controller =
      StreamController<TunnelPhase>.broadcast();

  FlutterVless? _engine;
  TunnelPhase _phase = TunnelPhase.idle;
  bool _initialised = false;

  /// Whether the last started tunnel actually got the hardened inbound.
  bool _lastConfigWasHardened = false;

  /// Exposed so the security screen can report real state, not a promise.
  bool get isSocksHardened => _lastConfigWasHardened;

  /// Completes when the engine reports `connected`, so [startTunnel] can
  /// await the handshake instead of returning while still connecting.
  Completer<void>? _connecting;

  @override
  TunnelPhase get phase => _phase;

  @override
  Stream<TunnelPhase> get phases async* {
    yield _phase;
    yield* _controller.stream;
  }

  void _emit(TunnelPhase next) {
    if (_phase == next) return;
    _phase = next;
    _controller.add(next);
  }

  /// Creates the native engine on first use.
  ///
  /// Deferred rather than done in the constructor: building the object must
  /// stay cheap and side-effect free so the app can start on platforms with
  /// no VPN backend at all.
  Future<FlutterVless> _ensureEngine() async {
    final existing = _engine;
    if (existing != null && _initialised) return existing;

    final engine = existing ?? FlutterVless(onStatusChanged: _onStatus);
    _engine = engine;

    if (!_initialised) {
      await engine.initializeVless(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
      _initialised = true;
    }
    return engine;
  }

  void _onStatus(VlessStatus status) {
    switch (status.connectionState) {
      case VlessConnectionState.connected:
        _emit(TunnelPhase.connected);
        final pending = _connecting;
        if (pending != null && !pending.isCompleted) pending.complete();
      case VlessConnectionState.connecting:
        _emit(TunnelPhase.establishing);
      case VlessConnectionState.disconnecting:
        _emit(TunnelPhase.disconnecting);
      case VlessConnectionState.disconnected:
      case VlessConnectionState.unknown:
        // A drop while we are still waiting means the handshake failed:
        // surface it instead of hanging until the timeout.
        final pending = _connecting;
        if (pending != null && !pending.isCompleted) {
          pending.completeError(
            const AppException('Tunnel closed before it came up'),
          );
        }
        _emit(TunnelPhase.idle);
    }
  }

  @override
  Future<void> startTunnel(ConnectionSource source, VpnConfig config) async {
    if (_phase == TunnelPhase.connected ||
        _phase == TunnelPhase.establishing) {
      return;
    }

    _emit(TunnelPhase.handshake);

    try {
      final engine = await _ensureEngine();

      final granted = await engine.requestPermission();
      if (!granted) {
        _emit(TunnelPhase.error);
        throw const AppException(
          'VPN permission was not granted. Android must allow the tunnel '
          'before it can start.',
        );
      }

      _emit(TunnelPhase.authenticating);

      // The plugin turns the share link into a full Xray configuration.
      // Malformed links throw here, before anything native is touched.
      final parsed = FlutterVless.parse(source.uri);
      final generated = parsed.getFullConfiguration();

      // NOTE ON THE LOCAL SOCKS5 HOLE (see xray_config_hardener.dart).
      //
      // Password auth on the local SOCKS inbound CANNOT be used with this
      // plugin: `tun2socks` is launched with a hardcoded, credential-free
      // proxy string —
      //     -proxy socks5://127.0.0.1:<port>
      // (flutter_vless_android/.../XrayVPNService.kt). Adding an account
      // makes every packet fail authentication, so the tunnel never carries
      // traffic. That is exactly what happened when this was enabled.
      //
      // Closing the hole for real means forking the plugin so tun2socks
      // receives the same credentials. Until then we do NOT pretend to be
      // protected: the flag below stays false and the security screen must
      // report the tunnel as vulnerable.
      final xrayConfig = generated;
      _lastConfigWasHardened = false;

      _emit(TunnelPhase.establishing);

      final done = Completer<void>();
      _connecting = done;

      await engine.startVless(
        remark: source.label,
        config: xrayConfig,
        proxyOnly: false,
      );

      // Native start returns immediately; the tunnel is only usable once the
      // status stream says so.
      await done.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw const AppException(
            'The server did not respond within 30 seconds. The key may be '
            'expired or the server unreachable.',
          );
        },
      );

      _logger.info(
        'Tunnel up via ${source.host} (${source.isImported ? 'imported' : 'nexa'})',
        source: 'vpn',
      );
    } on AppException {
      _connecting = null;
      _emit(TunnelPhase.error);
      rethrow;
    } catch (e) {
      _connecting = null;
      _emit(TunnelPhase.error);
      _logger.error('Tunnel failed: $e', source: 'vpn');
      throw AppException(_readableError(e));
    } finally {
      _connecting = null;
    }
  }

  /// Turns plugin/platform failures into something a user can act on.
  String _readableError(Object error) {
    if (error is ArgumentError) {
      return 'This key could not be read. Check that the full vless:// link '
          'was copied.';
    }
    if (error is TimeoutException) {
      return 'The server did not respond in time.';
    }
    return 'Could not start the tunnel: $error';
  }

  @override
  Future<int?> measurePing() async {
    final engine = _engine;
    if (engine == null || _phase != TunnelPhase.connected) return null;
    try {
      final ms = await engine.getConnectedServerDelay();
      // Движок возвращает отрицательное значение, когда замер не удался.
      // Показывать его как задержку нельзя.
      return ms > 0 ? ms : null;
    } catch (e) {
      _logger.warn('Ping probe failed: $e', source: 'vpn');
      return null;
    }
  }

  @override
  Future<void> stopTunnel() async {
    if (_phase == TunnelPhase.idle) return;
    _emit(TunnelPhase.disconnecting);
    try {
      await _engine?.stopVless();
    } catch (e) {
      _logger.warn('Stop reported an error: $e', source: 'vpn');
    }
    _emit(TunnelPhase.idle);
  }

  void dispose() {
    _controller.close();
  }
}
