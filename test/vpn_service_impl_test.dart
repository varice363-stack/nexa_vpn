import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/vpn_service_impl.dart';
import 'package:nexa_vpn/domain/services/tunnel_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';

/// Mock tunnel manager for testing
class MockTunnelManager implements TunnelManager {
  bool shouldFail = false;
  int startCallCount = 0;
  int stopCallCount = 0;
  TunnelPhase _currentPhase = TunnelPhase.idle;
  
  @override
  Stream<TunnelPhase> get phases async* {
    yield _currentPhase;
  }

  @override
  Future<void> startTunnel(ConnectionSource source, VpnConfig config) async {
    startCallCount++;
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
    return 50; // Mock ping
  }
}

void main() {
  group('VpnServiceImpl', () {
    late MockTunnelManager mockTunnel;
    late VpnServiceImpl vpnService;
    late AppLogger logger;

    setUp(() {
      mockTunnel = MockTunnelManager();
      logger = AppLogger();
      vpnService = VpnServiceImpl(
        tunnel: mockTunnel,
        configProvider: () => const VpnConfig(),
        logger: logger,
      );
    });

    test('initial status should be disconnected', () {
      expect(vpnService.status, VpnStatus.disconnected);
    });

    test('connect should call tunnel.startTunnel', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);

      expect(mockTunnel.startCallCount, 1);
    });

    test('disconnect should call tunnel.stopTunnel', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);
      await vpnService.disconnect();

      expect(mockTunnel.stopCallCount, 1);
    });

    test('metrics should track connection time', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);

      expect(vpnService.metrics.connectionTime, isNotNull);
      expect(vpnService.metrics.totalConnections, 1);
    });

    test('metrics should track disconnection', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);
      await vpnService.disconnect();

      expect(vpnService.metrics.totalDisconnections, 1);
      expect(vpnService.metrics.lastDisconnectedAt, isNotNull);
    });

    test('metrics should reset reconnect count on successful connection', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);
      expect(vpnService.metrics.reconnectCount, 0);
    });

    test('connect should throw when tunnel fails', () async {
      mockTunnel.shouldFail = true;
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      expect(
        () => vpnService.connect(source),
        throwsA(isA<Exception>()),
      );
    });

    test('should not connect if already connected to same source', () async {
      final source = ConnectionSource(
        id: 'test-key',
        label: 'Test Server',
        uri: 'vless://test@example.com:443',
      );

      await vpnService.connect(source);
      await vpnService.connect(source);

      expect(mockTunnel.startCallCount, 1);
    });

    test('should disconnect before connecting to different source', () async {
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
      await vpnService.connect(source2);

      expect(mockTunnel.stopCallCount, 1);
      expect(mockTunnel.startCallCount, 2);
    });
  });
}
