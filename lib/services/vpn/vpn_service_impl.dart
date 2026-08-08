import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/services/tunnel_manager.dart';
import '../../domain/services/vpn_service.dart';
import '../../models/server.dart';
import '../../models/vpn_config.dart';
import '../../models/vpn_status.dart';

/// [VpnService] built on top of a [TunnelManager].
///
/// Maps tunnel phases onto the public status stream and guards concurrent
/// connect/disconnect calls.
class VpnServiceImpl implements VpnService {
  VpnServiceImpl({
    required TunnelManager tunnel,
    required VpnConfig Function() configProvider,
    required AppLogger logger,
  })  : _tunnel = tunnel,
        _configProvider = configProvider,
        _logger = logger;

  final TunnelManager _tunnel;
  final VpnConfig Function() _configProvider;
  final AppLogger _logger;

  final StreamController<VpnStatus> _controller =
      StreamController<VpnStatus>.broadcast();

  StreamSubscription<TunnelPhase>? _phaseSub;
  Server? _activeServer;
  VpnStatus _status = VpnStatus.disconnected;
  bool _pendingDisconnect = false;

  @override
  VpnStatus get status => _status;

  @override
  Server? get activeServer => _activeServer;

  @override
  Stream<VpnStatus> get statuses async* {
    yield _status;
    yield* _controller.stream;
  }

  void init() {
    _phaseSub = _tunnel.phases.listen(_onPhase);
  }

  void _onPhase(TunnelPhase phase) {
    final previous = _status;
    _status = switch (phase) {
      TunnelPhase.idle => _pendingDisconnect
          ? VpnStatus.disconnected
          : VpnStatus.disconnected,
      TunnelPhase.handshake ||
      TunnelPhase.authenticating ||
      TunnelPhase.establishing =>
        VpnStatus.connecting,
      TunnelPhase.connected => VpnStatus.connected,
      TunnelPhase.disconnecting => VpnStatus.disconnecting,
      TunnelPhase.error => VpnStatus.error,
    };
    if (phase == TunnelPhase.connected && _pendingDisconnect) {
      _pendingDisconnect = false;
    }
    if (_status != previous) _controller.add(_status);
  }

  @override
  Future<void> connect(Server server) async {
    if (_status == VpnStatus.connected && _activeServer?.id == server.id) {
      return;
    }
    if (_status == VpnStatus.connecting ||
        _status == VpnStatus.disconnecting) {
      return;
    }
    _logger.info(
      'Connecting to ${server.country} · ${server.city} '
      '(${_configProvider().protocol.label})',
      source: 'vpn',
    );
    _activeServer = server;
    _pendingDisconnect = false;
    try {
      await _tunnel.startTunnel(server, _configProvider());
      _logger.info('Connected to ${server.displayName}', source: 'vpn');
    } on AppException catch (e) {
      _logger.error('Tunnel failed: $e', source: 'vpn');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_status == VpnStatus.disconnected ||
        _status == VpnStatus.disconnecting) {
      return;
    }
    _pendingDisconnect = true;
    _logger.info('Disconnecting…', source: 'vpn');
    await _tunnel.stopTunnel();
    _activeServer = null;
    _logger.info('Disconnected', source: 'vpn');
  }

  void dispose() {
    _phaseSub?.cancel();
    _controller.close();
  }
}
