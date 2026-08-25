import '../../models/connection_source.dart';
import '../../models/vpn_status.dart';

/// High-level VPN control surface used by the UI layer.
abstract class VpnService {
  /// Stream of status changes; emits the current status immediately.
  Stream<VpnStatus> get statuses;

  VpnStatus get status;

  /// Endpoint the tunnel is connected to (or connecting), if any.
  ConnectionSource? get activeSource;

  /// Connects to [source]. No-op if already connected to it.
  ///
  /// [source] may be a key we issued or one the user imported — the service
  /// draws no distinction.
  Future<void> connect(ConnectionSource source);

  /// Disconnects. No-op if already disconnected.
  Future<void> disconnect();
}
