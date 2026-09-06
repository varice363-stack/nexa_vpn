import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';
import 'package:nexa_vpn/domain/repositories/session_manager.dart';
import 'package:nexa_vpn/domain/services/vpn_service.dart';
import 'package:nexa_vpn/models/connection_session.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/connection_manager_impl.dart';

/// Mock VpnService for testing
class MockVpnService implements VpnService {
  final _statusController = StreamController<VpnStatus>.broadcast();
  VpnStatus _status = VpnStatus.disconnected;
  ConnectionSource? _activeSource;

  @override
  Stream<VpnStatus> get statuses => _statusController.stream;

  @override
  VpnStatus get status => _status;

  @override
  ConnectionSource? get activeSource => _activeSource;

  @override
  Future<void> connect(ConnectionSource source) async {
    _activeSource = source;
    _status = VpnStatus.connecting;
    _statusController.add(_status);
    _status = VpnStatus.connected;
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = VpnStatus.disconnecting;
    _statusController.add(_status);
    _status = VpnStatus.disconnected;
    _statusController.add(_status);
    // Delay clearing activeSource so ConnectionManagerImpl._endSession()
    // can read it before it's nulled (matches real async timing).
    Future.microtask(() => _activeSource = null);
  }

  void dispose() => _statusController.close();
}

/// Mock SessionManager for testing
class MockSessionManager implements SessionManager {
  final List<ConnectionSession> sessions = [];

  @override
  Future<List<ConnectionSession>> getSessions() async => sessions;

  @override
  Future<void> addSession(ConnectionSession session) async {
    sessions.add(session);
  }

  @override
  Future<void> clear() async {
    sessions.clear();
  }
}

void main() {
  group('ConnectionManagerImpl', () {
    late MockVpnService mockService;
    late MockSessionManager mockSessions;
    late ConnectionManagerImpl manager;
    late AppLogger logger;

    setUp(() {
      mockService = MockVpnService();
      mockSessions = MockSessionManager();
      logger = AppLogger();
      manager = ConnectionManagerImpl(logger: logger);
    });

    tearDown(() {
      manager.dispose();
      mockService.dispose();
    });

    test('initial stats should be empty', () {
      expect(manager.current.bytesDown, 0);
      expect(manager.current.bytesUp, 0);
      expect(manager.current.duration, Duration.zero);
    });

    test('bind should subscribe to VpnService status', () async {
      manager.bind(mockService, mockSessions);

      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
        origin: ConnectionOrigin.imported,
      );

      await mockService.connect(source);

      // Wait for the ticker to fire at least once
      await Future.delayed(const Duration(milliseconds: 1500));

      expect(manager.current.startedAt, isNotNull);
      expect(manager.current.bytesDown, greaterThan(0));
    });

    test('stats should update over time when connected', () async {
      manager.bind(mockService, mockSessions);

      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
        origin: ConnectionOrigin.imported,
      );

      await mockService.connect(source);

      // Wait for ticker updates
      await Future.delayed(const Duration(seconds: 3));

      final stats = manager.current;
      expect(stats.bytesDown, greaterThan(0));
      expect(stats.bytesUp, greaterThan(0));
      expect(stats.speedDown, greaterThan(0));
      expect(stats.speedUp, greaterThan(0));
    });

    test('session should be persisted on disconnect', () async {
      manager.bind(mockService, mockSessions);

      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
        origin: ConnectionOrigin.imported,
      );

      await mockService.connect(source);
      await Future.delayed(const Duration(milliseconds: 1500));
      await mockService.disconnect();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockSessions.sessions, hasLength(1));
      expect(mockSessions.sessions.first.serverName, 'Test Server');
    });

    test('stats stream should emit updates', () async {
      manager.bind(mockService, mockSessions);

      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
        origin: ConnectionOrigin.imported,
      );

      final statsList = <dynamic>[];
      final sub = manager.stats.listen(statsList.add);

      await mockService.connect(source);
      await Future.delayed(const Duration(seconds: 2));

      await sub.cancel();

      // Should have received at least the initial value + updates
      expect(statsList.length, greaterThan(1));
    });
  });
}
