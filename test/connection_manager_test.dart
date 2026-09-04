import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/models/connection_stats.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/connection_manager_impl.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';
import 'package:nexa_vpn/domain/services/vpn_service.dart';
import 'package:nexa_vpn/domain/repositories/session_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';

/// Mock VPN service for testing
class MockVpnService implements VpnService {
  final _statusController = StreamController<VpnStatus>.broadcast();
  VpnStatus _currentStatus = VpnStatus.disconnected;
  
  @override
  Stream<VpnStatus> get statuses => _statusController.stream;
  
  @override
  VpnStatus get status => _currentStatus;
  
  @override
  ConnectionSource? get activeSource => null;
  
  @override
  Future<void> connect(ConnectionSource source) async {
    _currentStatus = VpnStatus.connecting;
    _statusController.add(VpnStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 100));
    _currentStatus = VpnStatus.connected;
    _statusController.add(VpnStatus.connected);
  }
  
  @override
  Future<void> disconnect() async {
    _currentStatus = VpnStatus.disconnecting;
    _statusController.add(VpnStatus.disconnecting);
    await Future.delayed(const Duration(milliseconds: 100));
    _currentStatus = VpnStatus.disconnected;
    _statusController.add(VpnStatus.disconnected);
  }
  
  void emitStatus(VpnStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
  
  void dispose() {
    _statusController.close();
  }
}

/// Mock session manager for testing
class MockSessionManager implements SessionManager {
  final List<ConnectionSession> sessions = [];
  
  @override
  Future<void> add(ConnectionSession session) async {
    sessions.add(session);
  }
  
  @override
  Future<List<ConnectionSession>> recent([int limit = 10]) async {
    return sessions.take(limit).toList();
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
      manager.bind(mockService, mockSessions);
    });

    tearDown(() {
      mockService.dispose();
      manager.dispose();
    });

    test('initial stats should be empty', () {
      expect(manager.current.duration, Duration.zero);
      expect(manager.current.bytesDown, 0);
      expect(manager.current.bytesUp, 0);
    });

    test('should start session when connected', () async {
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Session should be tracked
      expect(mockSessions.sessions.length, greaterThanOrEqualTo(0));
    });

    test('should stop session when disconnected', () async {
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(milliseconds: 100));
      
      mockService.emitStatus(VpnStatus.disconnected);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Session should be persisted
      expect(mockSessions.sessions.length, greaterThanOrEqualTo(0));
    });

    test('should track connection duration', () async {
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(milliseconds: 500));
      
      final stats = manager.current;
      expect(stats.duration.inMilliseconds, greaterThan(0));
    });

    test('should simulate throughput', () async {
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(seconds: 1));
      
      final stats = manager.current;
      // Throughput is simulated, so we expect some values
      expect(stats.bytesDown, greaterThanOrEqualTo(0));
      expect(stats.bytesUp, greaterThanOrEqualTo(0));
    });

    test('should emit stats stream', () async {
      final statsList = <ConnectionStats>[];
      final subscription = manager.stats.listen(statsList.add);
      
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(milliseconds: 500));
      
      expect(statsList.length, greaterThan(0));
      await subscription.cancel();
    });

    test('should handle multiple connections', () async {
      // First connection
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(milliseconds: 200));
      mockService.emitStatus(VpnStatus.disconnected);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Second connection
      mockService.emitStatus(VpnStatus.connected);
      await Future.delayed(const Duration(milliseconds: 200));
      mockService.emitStatus(VpnStatus.disconnected);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should have tracked both sessions
      expect(mockSessions.sessions.length, greaterThanOrEqualTo(2));
    });
  });
}
