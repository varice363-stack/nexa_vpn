import '../../models/server.dart';
import '../../models/vpn_status.dart';

/// High-level VPN control surface used by the UI layer.
abstract class VpnService {
  /// Stream of status changes; emits the current status immediately.
  Stream<VpnStatus> get statuses;

  VpnStatus get status;

  /// Server the tunnel is connected to (or connecting), if any.
  Server? get activeServer;

  /// Connects to [server]. No-op if already connected to it.
  Future<void> connect(Server server);

  /// Disconnects. No-op if already disconnected.
  Future<void> disconnect();
}
