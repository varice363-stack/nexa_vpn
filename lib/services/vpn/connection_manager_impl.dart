import 'dart:async';

import '../../core/utils/app_logger.dart';
import '../../domain/repositories/session_manager.dart';
import '../../domain/services/connection_manager.dart';
import '../../domain/services/vpn_service.dart';
import '../../models/connection_session.dart';
import '../../models/connection_stats.dart';
import '../../models/tunnel_traffic.dart';
import '../../models/vpn_status.dart';

/// Tracks the active session and persists it on completion.
///
/// Объём и скорость берутся из счётчиков туннеля ([VpnService.traffic]),
/// а не генерируются здесь.
class ConnectionManagerImpl implements ConnectionManager {
  ConnectionManagerImpl({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  final StreamController<ConnectionStats> _controller =
      StreamController<ConnectionStats>.broadcast();

  StreamSubscription<VpnStatus>? _statusSub;
  StreamSubscription<TunnelTraffic>? _trafficSub;
  Timer? _ticker;
  VpnService? _service;
  SessionManager? _sessions;

  // Live session state.
  DateTime? _startedAt;
  int _bytesDown = 0;
  int _bytesUp = 0;
  double _speedDown = 0;
  double _speedUp = 0;

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
    _trafficSub = service.traffic.listen(_onTraffic);
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

  /// Счётчики приходят от туннеля раз в секунду. Скорость переводим из байт/с
  /// в Мбит/с: так её показывает главный экран.
  void _onTraffic(TunnelTraffic t) {
    if (_startedAt == null) return;
    _bytesDown = t.downloadBytes;
    _bytesUp = t.uploadBytes;
    _speedDown = t.downloadBytesPerSec * 8 / 1000000;
    _speedUp = t.uploadBytesPerSec * 8 / 1000000;
    _emit();
  }

  void _startSession() {
    _startedAt = DateTime.now();
    _bytesDown = 0;
    _bytesUp = 0;
    _speedDown = 0;
    _speedUp = 0;
    _emit();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  void _emit() {
    if (_startedAt == null) return;
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
    _speedDown = 0;
    _speedUp = 0;
    // Последний снимок не должен хранить скорость отключённого туннеля.
    _current = _current.copyWith(speedDown: 0, speedUp: 0);
    if (!_controller.isClosed) _controller.add(_current);
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
    _trafficSub?.cancel();
    _controller.close();
  }
}
