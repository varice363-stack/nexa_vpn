import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/vpn_service_impl.dart';
import 'package:nexa_vpn/domain/services/tunnel_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';

/// Mock tunnel manager for metrics testing
class MockTunnelManagerForMetrics implements TunnelManager {
  bool shouldFail = false;
  int startCallCount = 0;
  int stopCallCount = 0;
  TunnelPhase _currentPhase = TunnelPhase.idle;
  Duration? connectionDelay;
  
  @override
  Stream<TunnelPhase> get phases async* {
    yield _currentPhase;
  }

  @override
  Future<void> startTunnel(ConnectionSource source, VpnConfig config) async {
    startCallCount++;
    if (connectionDelay != null) {
      await Future.delayed(connectionDelay!);
    }
    if (shouldFail) {
      _currentPhase = TunnelPhase.error;
      throw Exception('Mock tunnel error');
    }
    _currentPhase = TunnelPhase.connected;
  }

  @override
  Future<void> stopTunnel() async {
    stopCallCount++;
    _currentPhase = TunnelPhase.idle;
  }

  @override
  Future<int?> measurePing() async {
    return 50;
  }
}

void main() {
  group('VpnMetrics', () {
    late MockTunnelManagerForMetrics mockTunnel;
    late VpnServiceImpl vpnService;
    late AppLogger logger;

    setUp(() {
      mockTunnel = MockTunnelManagerForMetrics();
      logger = AppLogger();
      vpnService = VpnServiceImpl(
        tunnel: mockTunnel,
        configProvider: () => const VpnConfig(),
        logger: logger,
      );
    });

    test('metrics should be initially empty', () {
      final metrics = vpnService.metrics;
      expect(metrics.connectionTime, isNull);
      expect(metrics.reconnectCount, 0);
      expect(metrics.lastConnectedAt, isNull);
      expect(metrics.lastDisconnectedAt, isNull);
      expect(metrics.totalConnections, 0);
      expect(metrics.totalDisconnections, 0);
    });

    test('metrics should track connection time', () async {
      mockTunnel.connectionDelay = const Duration(milliseconds: 100);
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);

      final metrics = vpnService.metrics;
      expect(metrics.connectionTime, isNotNull);
      expect(metrics.connectionTime!.inMilliseconds, greaterThan(0));
      expect(metrics.lastConnectedAt, isNotNull);
      expect(metrics.totalConnections, 1);
    });

    test('metrics should track multiple connections', () async {
      final source1 = ConnectionSource(
        id: 'test-key-1',
        label: 'Test Server 1',
        uri: 'vless://test1@example.com:443',
      );
      final source2 = ConnectionSource(
        id: 'test-key-2',
        label: 'Test Server 2',
        uri: 'vless://test2@example.com:443',
      );

      await vpnService.connect(source1);
      await vpnService.disconnect();
      await vpnService.connect(source2);

      final metrics = vpnService.metrics;
      expect(metrics.totalConnections, 2);
      expect(metrics.totalDisconnections, 1);
    });

    test('metrics should track disconnection time', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);
      await vpnService.disconnect();

      final metrics = vpnService.metrics;
      expect(metrics.lastDisconnectedAt, isNotNull);
      expect(metrics.totalDisconnections, 1);
    });

    test('metrics should reset reconnect count on successful connection', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);
      
      final metrics = vpnService.metrics;
      expect(metrics.reconnectCount, 0);
    });

    test('metrics should handle rapid connect/disconnect cycles', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      // Rapid cycle
      for (int i = 0; i < 5; i++) {
        await vpnService.connect(source);
        await vpnService.disconnect();
      }

      final metrics = vpnService.metrics;
      expect(metrics.totalConnections, 5);
      expect(metrics.totalDisconnections, 5);
    });

    test('metrics connection time should be reasonable', () async {
      mockTunnel.connectionDelay = const Duration(milliseconds: 200);
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);

      final metrics = vpnService.metrics;
      // Connection time should be at least the delay we set
      expect(metrics.connectionTime!.inMilliseconds, greaterThanOrEqualTo(200));
      // But not too long (should be under 1 second for test)
      expect(metrics.connectionTime!.inSeconds, lessThan(1));
    });

    test('metrics should handle connection failures gracefully', () async {
      mockTunnel.shouldFail = true;
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      try {
        await vpnService.connect(source);
      } catch (e) {
        // Expected to fail
      }

      final metrics = vpnService.metrics;
      // Metrics should still be valid
      expect(metrics.totalConnections, 0); // Failed connection not counted
      expect(metrics.connectionTime, isNull);
    });
  });
}
