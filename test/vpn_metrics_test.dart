import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/services/vpn/vpn_service_impl.dart';
import 'package:nexa_vpn/domain/services/tunnel_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';

/// Mock tunnel manager for metrics testing
class MockTunnelManager implements TunnelManager {
  TunnelPhase _currentPhase = TunnelPhase.idle;

  @override
  Stream<TunnelPhase> get phases async* {
    yield _currentPhase;
  }

  @override
  Future<void> startTunnel(ConnectionSource source, VpnConfig config) async {
    _currentPhase = TunnelPhase.connected;
  }

  @override
  Future<void> stopTunnel() async {
    _currentPhase = TunnelPhase.idle;
  }

  @override
  Future<int?> measurePing() async => 50;

  @override
  TunnelPhase get phase => _currentPhase;
}

ConnectionSource _testSource(String id) {
  return ConnectionSource(
    id: id,
    label: 'Test',
    uri: 'vless://test@example.com:443',
    origin: ConnectionOrigin.imported,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VpnMetrics', () {
    late MockTunnelManager mockTunnel;
    late VpnServiceImpl vpnService;

    setUp(() {
      mockTunnel = MockTunnelManager();
      vpnService = VpnServiceImpl(
        tunnel: mockTunnel,
        configProvider: () => const VpnConfig(),
        logger: AppLogger(),
      );
    });

    test('should initialize with zero values', () {
      expect(vpnService.metrics.totalConnections, 0);
      expect(vpnService.metrics.totalDisconnections, 0);
      expect(vpnService.metrics.reconnectCount, 0);
    });

    test('should increment totalConnections on connect', () async {
      await vpnService.connect(_testSource('key-1'));
      expect(vpnService.metrics.totalConnections, 1);

      await vpnService.connect(_testSource('key-2'));
      expect(vpnService.metrics.totalConnections, 2);
    });

    test('should increment totalDisconnections on disconnect', () async {
      await vpnService.connect(_testSource('key-1'));
      await vpnService.disconnect();
      expect(vpnService.metrics.totalDisconnections, 1);
    });

    test('should track connection time', () async {
      expect(vpnService.metrics.connectionTime, isNull);
      
      await vpnService.connect(_testSource('key-1'));
      expect(vpnService.metrics.connectionTime, isNotNull);

      await vpnService.disconnect();
      expect(vpnService.metrics.lastDisconnectedAt, isNotNull);
    });

    test('should provide copyWith for metrics updates', () {
      final original = vpnService.metrics;
      expect(original.totalConnections, 0);
      
      // Metrics are updated internally, not externally
      // Just verify copyWith works
      final updated = original.copyWith(totalConnections: 5);
      expect(updated.totalConnections, 5);
      expect(original.totalConnections, 0); // Original unchanged
    });
  });
}
