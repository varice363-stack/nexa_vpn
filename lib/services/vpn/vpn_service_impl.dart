import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/services/tunnel_manager.dart';
import '../../domain/services/vpn_service.dart';
import '../../models/connection_source.dart';
import '../../models/vpn_config.dart';
import '../../models/vpn_status.dart';

/// Performance metrics for VPN connection.
class VpnMetrics {
  final Duration? connectionTime;
  final int reconnectCount;
  final DateTime? lastConnectedAt;
  final DateTime? lastDisconnectedAt;
  final int totalConnections;
  final int totalDisconnections;

  const VpnMetrics({
    this.connectionTime,
    this.reconnectCount = 0,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    this.totalConnections = 0,
    this.totalDisconnections = 0,
  });

  VpnMetrics copyWith({
    Duration? connectionTime,
    int? reconnectCount,
    DateTime? lastConnectedAt,
    DateTime? lastDisconnectedAt,
    int? totalConnections,
    int? totalDisconnections,
  }) {
    return VpnMetrics(
      connectionTime: connectionTime ?? this.connectionTime,
      reconnectCount: reconnectCount ?? this.reconnectCount,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastDisconnectedAt: lastDisconnectedAt ?? this.lastDisconnectedAt,
      totalConnections: totalConnections ?? this.totalConnections,
      totalDisconnections: totalDisconnections ?? this.totalDisconnections,
    );
  }
}

/// [VpnService] built on top of a [TunnelManager].
///
/// Maps tunnel phases onto the public status stream and guards concurrent
/// connect/disconnect calls.
///
/// Supports auto-reconnect: when network connectivity is lost while connected,
/// the service waits for restoration and automatically reconnects.
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ConnectionSource? _activeSource;
  VpnStatus _status = VpnStatus.disconnected;
  bool _pendingDisconnect = false;
  bool _autoReconnectEnabled = true;
  Timer? _reconnectDebounce;
  
  // Performance metrics
  VpnMetrics _metrics = const VpnMetrics();
  DateTime? _connectionStartTime;
  int _currentReconnectCount = 0;

  /// Get current VPN performance metrics
  VpnMetrics get metrics => _metrics;

  @override
  VpnStatus get status => _status;

  @override
  ConnectionSource? get activeSource => _activeSource;

  @override
  Stream<VpnStatus> get statuses async* {
    yield _status;
    yield* _controller.stream;
  }

  void init() {
    _phaseSub = _tunnel.phases.listen(_onPhase);
    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (_status == VpnStatus.connected && !hasNetwork) {
      // Lost network while connected — prepare for reconnect
      _logger.info('Network lost, waiting for restoration…', source: 'vpn');
      _reconnectDebounce?.cancel();
    } else if (_status == VpnStatus.reconnecting && hasNetwork) {
      // Network restored while reconnecting — trigger reconnect
      _reconnectDebounce?.cancel();
      _reconnectDebounce = Timer(const Duration(seconds: 2), () {
        _performAutoReconnect();
      });
    }
  }

  Future<void> _performAutoReconnect() async {
    final source = _activeSource;
    if (source == null) return;

    _currentReconnectCount++;
    _logger.info('Auto-reconnecting to ${source.label} (attempt $_currentReconnectCount)…', source: 'vpn');
    
    // Update metrics
    _metrics = _metrics.copyWith(
      reconnectCount: _currentReconnectCount,
    );

    try {
      // Stop current tunnel first
      await _tunnel.stopTunnel();
      await Future.delayed(const Duration(milliseconds: 500));

      // Reconnect
      await _tunnel.startTunnel(source, _configProvider());
      _logger.info('Auto-reconnect successful', source: 'vpn');
    } catch (e) {
      _logger.error('Auto-reconnect failed: $e', source: 'vpn');
      // Status will be set to error by _onPhase
    }
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
        _status == VpnStatus.reconnecting
            ? VpnStatus.reconnecting
            : VpnStatus.connecting,
      TunnelPhase.connected => VpnStatus.connected,
      TunnelPhase.disconnecting => VpnStatus.disconnecting,
      TunnelPhase.error => VpnStatus.error,
    };
    if (phase == TunnelPhase.connected && _pendingDisconnect) {
      _pendingDisconnect = false;
    }

    // If connection drops unexpectedly and we have an active source,
    // prepare for auto-reconnect
    if (phase == TunnelPhase.idle && _activeSource != null &&
        previous == VpnStatus.connected && _autoReconnectEnabled) {
      _status = VpnStatus.reconnecting;
      _logger.info('Connection dropped, entering reconnect state', source: 'vpn');
    }

    if (_status != previous) _controller.add(_status);
  }

  @override
  Future<void> connect(ConnectionSource source) async {
    if (_status == VpnStatus.connected && _activeSource?.id == source.id) {
      return;
    }
    if (_status == VpnStatus.connecting ||
        _status == VpnStatus.disconnecting) {
      return;
    }
    _logger.info(
      'Connecting to ${source.label} · ${source.host}',
      source: 'vpn',
    );
    _activeSource = source;
    _pendingDisconnect = false;
    _reconnectDebounce?.cancel();
    _connectionStartTime = DateTime.now();
    try {
      await _tunnel.startTunnel(source, _configProvider());
      final connectionTime = DateTime.now().difference(_connectionStartTime!);
      _logger.info('Connected to ${source.label} in ${connectionTime.inMilliseconds}ms', source: 'vpn');
      
      // Update metrics
      _metrics = _metrics.copyWith(
        connectionTime: connectionTime,
        lastConnectedAt: DateTime.now(),
        totalConnections: _metrics.totalConnections + 1,
      );
      _currentReconnectCount = 0; // Reset reconnect count on successful connection
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
    _reconnectDebounce?.cancel();
    _logger.info('Disconnecting…', source: 'vpn');
    await _tunnel.stopTunnel();
    _activeSource = null;
    _logger.info('Disconnected', source: 'vpn');
    
    // Update metrics
    _metrics = _metrics.copyWith(
      lastDisconnectedAt: DateTime.now(),
      totalDisconnections: _metrics.totalDisconnections + 1,
    );
    _connectionStartTime = null;
  }

  void dispose() {
    _phaseSub?.cancel();
    _connectivitySub?.cancel();
    _reconnectDebounce?.cancel();
    _controller.close();
  }
}
