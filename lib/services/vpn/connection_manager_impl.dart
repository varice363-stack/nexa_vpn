import 'dart:async';

import '../../core/utils/app_logger.dart';
import '../../domain/repositories/session_manager.dart';
import '../../domain/services/connection_manager.dart';
import '../../domain/services/vpn_service.dart';
import '../../models/connection_session.dart';
import '../../models/connection_stats.dart';
import '../../models/vpn_status.dart';

/// Tracks the active session and persists it on completion.
///
/// Throughput is simulated (deterministic pseudo-random walk) until the
/// native tunnel reports real byte counters — see [TunnelManager] docs.
class ConnectionManagerImpl implements ConnectionManager {
  ConnectionManagerImpl({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  final StreamController<ConnectionStats> _controller =
      StreamController<ConnectionStats>.broadcast();

  StreamSubscription<VpnStatus>? _statusSub;
  Timer? _ticker;
  VpnService? _service;
  SessionManager? _sessions;

  // Live session state.
  DateTime? _startedAt;
  int _bytesDown = 0;
  int _bytesUp = 0;
  double _speedDown = 0;
  double _speedUp = 0;
  int _sessionIndex = 0;

  ConnectionStats _current = const ConnectionStats();

  @override
  ConnectionStats get current => _current;

  @override
  Stream<ConnectionStats> get stats async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  void bind(VpnService service, SessionManager sessions) {
    _service = service;
    _sessions = sessions;
    _statusSub = service.statuses.listen(_onStatus);
  }

  void _onStatus(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        _startSession();
      case VpnStatus.connecting:
      case VpnStatus.disconnecting:
      case VpnStatus.reconnecting:
        break;
      case VpnStatus.disconnected:
        _endSession();
      case VpnStatus.error:
        _endSession();
    }
  }

  void _startSession() {
    _startedAt = DateTime.now();
    _bytesDown = 0;
    _bytesUp = 0;
    _sessionIndex = _sessionIndex + 1;
    _emit();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  void _emit() {
    if (_startedAt == null) return;
    // Simulated throughput: 60–180 Mbps down, 25–80 Mbps up.
    _speedDown = 60 + (_sessionIndex * 37 + _bytesDown ~/ 500000) % 120;
    _speedUp = 25 + (_sessionIndex * 13 + _bytesUp ~/ 300000) % 55;
    _bytesDown += (_speedDown * 1024 * 1024 / 8).round();
    _bytesUp += (_speedUp * 1024 * 1024 / 8).round();
    _current = ConnectionStats(
      startedAt: _startedAt,
      duration: DateTime.now().difference(_startedAt!),
      bytesDown: _bytesDown,
      bytesUp: _bytesUp,
      speedDown: _speedDown,
      speedUp: _speedUp,
    );
    if (!_controller.isClosed) _controller.add(_current);
  }

  Future<void> _endSession() async {
    _ticker?.cancel();
    _ticker = null;
    final startedAt = _startedAt;
    final service = _service;
    if (startedAt == null || service == null) return;

    final session = ConnectionSession(
      serverId: service.activeSource?.id ?? 'unknown',
      serverName: service.activeSource?.label ?? 'Unknown',
      startedAt: startedAt,
      endedAt: DateTime.now(),
      bytesDown: _bytesDown,
      bytesUp: _bytesUp,
    );
    _startedAt = null;
    try {
      await _sessions?.addSession(session);
    } catch (e) {
      _logger.warn('Failed to persist session: $e', source: 'vpn');
    }
    _logger.info(
      'Session saved: ${session.serverName} '
      '(${session.duration.inMinutes} min)',
      source: 'vpn',
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _statusSub?.cancel();
    _controller.close();
  }
}
