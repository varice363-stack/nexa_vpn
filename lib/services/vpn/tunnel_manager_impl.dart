import 'dart:async';

import '../../domain/services/tunnel_manager.dart';
import '../../models/server.dart';
import '../../models/vpn_config.dart';
import '../../models/vpn_status.dart';

/// Simulated tunnel with the exact lifecycle of a real VPN handshake.
///
/// NATIVE INTEGRATION (TODO — platform engineers):
/// Replace the timer-driven phase machine with a real tunnel:
///   1. WireGuard: `wireguard_flutter` — expose a `WireGuardTunnelManager`
///      implementing [TunnelManager], mapping tunnel status callbacks onto
///      [TunnelPhase].
///   2. OpenVPN: OpenVPN3 (`ovpn3` / `dart_openvpn3`) — same mapping.
///   3. IKEv2: `NetworkExtension` (iOS) / `VpnService` (Android) platform
///      channels.
/// The rest of the app (UI, providers, session tracking) depends only on
/// [TunnelManager], so swapping this class is the single integration point.
class MockTunnelManager implements TunnelManager {
  MockTunnelManager();

  final StreamController<TunnelPhase> _controller =
      StreamController<TunnelPhase>.broadcast();

  TunnelPhase _phase = TunnelPhase.idle;
  Timer? _timer;
  final List<TunnelPhase> _connectingSequence = const [
    TunnelPhase.handshake,
    TunnelPhase.authenticating,
    TunnelPhase.establishing,
    TunnelPhase.connected,
  ];
  final List<Duration> _connectingDurations = const [
    Duration(milliseconds: 550),
    Duration(milliseconds: 650),
    Duration(milliseconds: 750),
  ];

  @override
  TunnelPhase get phase => _phase;

  @override
  Stream<TunnelPhase> get phases async* {
    yield _phase;
    yield* _controller.stream;
  }

  @override
  Future<void> startTunnel(Server server, VpnConfig config) async {
    if (_phase == TunnelPhase.connected ||
        _phase == TunnelPhase.establishing) {
      return;
    }
    _phase = TunnelPhase.handshake;
    _controller.add(_phase);

    for (var i = 0; i < _connectingDurations.length; i++) {
      await Future<void>.delayed(_connectingDurations[i]);
      _phase = _connectingSequence[i + 1];
      _controller.add(_phase);
    }
  }

  @override
  Future<void> stopTunnel() async {
    if (_phase == TunnelPhase.idle) return;
    _phase = TunnelPhase.disconnecting;
    _controller.add(_phase);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _phase = TunnelPhase.idle;
    _controller.add(_phase);
  }

  /// Simulated failure injection for diagnostics / error handling demo.
  Future<void> forceError() async {
    _phase = TunnelPhase.error;
    _controller.add(_phase);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _phase = TunnelPhase.idle;
    _controller.add(_phase);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
