import '../../models/server.dart';
import '../../models/vpn_config.dart';
import '../../models/vpn_status.dart';

/// Low-level tunnel lifecycle.
///
/// ARCHITECTURE NOTE (native integration):
/// The production implementation must wrap a native tunnel:
///   * WireGuard — `wireguard_flutter` / kernel module via platform channel;
///   * OpenVPN — OpenVPN3 client integration (`ovpn3` bindings);
///   * IKEv2 — NetworkExtension (`NEVPNManager`) on iOS / `VpnService` on
///     Android.
/// Until a native module is available, [TunnelManager] is implemented by a
/// simulated state machine (`MockTunnelManager`) with identical semantics.
abstract class TunnelManager {
  /// Stream of tunnel phases; emits the current phase immediately on listen.
  Stream<TunnelPhase> get phases;

  TunnelPhase get phase;

  /// Starts the tunnel to [server] with [config].
  ///
  /// Completes when the tunnel reaches `connected`, or throws an
  /// [AppException] on failure.
  Future<void> startTunnel(Server server, VpnConfig config);

  /// Tears the tunnel down. Safe to call when idle.
  Future<void> stopTunnel();
}
