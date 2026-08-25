import '../../models/connection_source.dart';
import '../../models/vpn_config.dart';
import '../../models/vpn_status.dart';

/// Low-level tunnel lifecycle.
///
/// The tunnel is driven by a [ConnectionSource] — the VLESS endpoint the user
/// chose — rather than by a catalog [Server]. That is deliberate: a key the
/// user imported from another provider points at a host we know nothing about,
/// and it must connect exactly as well as a key we sold. Anything that
/// required our own server metadata would quietly break that promise.
///
/// Implementations:
///   * `XrayTunnelManager` — production, wraps `flutter_vless` (Xray-core);
///   * `MockTunnelManager` — simulated phases, used in tests and on platforms
///     without a native backend.
abstract class TunnelManager {
  /// Stream of tunnel phases; emits the current phase immediately on listen.
  Stream<TunnelPhase> get phases;

  TunnelPhase get phase;

  /// Starts the tunnel to [source] with [config].
  ///
  /// Completes when the tunnel reaches `connected`, or throws an
  /// [AppException] on failure.
  Future<void> startTunnel(ConnectionSource source, VpnConfig config);

  /// Tears the tunnel down. Safe to call when idle.
  Future<void> stopTunnel();

  /// Задержка до сервера через уже поднятый туннель, в миллисекундах.
  ///
  /// Возвращает null, если туннель не поднят или замер не удался — вызывающий
  /// код обязан показать прочерк, а не выдуманное число.
  Future<int?> measurePing();
}
