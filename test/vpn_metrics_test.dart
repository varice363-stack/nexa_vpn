import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/services/vpn/vpn_service_impl.dart';
import 'package:nexa_vpn/domain/services/tunnel_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';

/// Mock tunnel manager that emits phase changes via a broadcast stream,
/// so VpnServiceImpl.init() can subscribe and observe them.
class MockTunnelManager implements TunnelManager {
  final StreamController<TunnelPhase> _controller =
      StreamController<TunnelPhase>.broadcast();
  TunnelPhase _currentPhase = TunnelPhase.idle;

  @override
  TunnelPhase get phase => _currentPhase;

  @override
  Stream<TunnelPhase> get phases => _controller.stream;

  void _setPhase(TunnelPhase p) {
    _currentPhase = p;
    _controller.add(p);
  }

  @override
  Future<void> startTunnel(ConnectionSource source, VpnConfig config) async {
    _setPhase(TunnelPhase.connected);
  }

  @override
  Future<void> stopTunnel() async {
    _setPhase(TunnelPhase.idle);
  }

  @override
  Future<int?> measurePing() async => 50;

  void dispose() => _controller.close();
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
      vpnService.init();
    });

    tearDown(() {
      vpnService.dispose();
      mockTunnel.dispose();
    });

    test('should initialize with zero values', () {
      expect(vpnService.metrics.totalConnections, 0);
      expect(vpnService.metrics.totalDisconnections, 0);
      expect(vpnService.metrics.reconnectCount, 0);
    });

    test('should increment totalConnections on connect', () async {
      await vpnService.connect(_testSource('key-1'));
      await Future.delayed(Duration.zero);
      expect(vpnService.metrics.totalConnections, 1);

      await vpnService.connect(_testSource('key-2'));
      await Future.delayed(Duration.zero);
      expect(vpnService.metrics.totalConnections, 2);
    });

    test('should increment totalDisconnections on disconnect', () async {
      final source = _testSource('key-1');
      await vpnService.connect(source);
      await Future.delayed(Duration.zero);
      expect(vpnService.status, VpnStatus.connected);

      await vpnService.disconnect();
      await Future.delayed(Duration.zero);
      expect(vpnService.metrics.totalDisconnections, 1);
    });

    test('should track connection time', () async {
      expect(vpnService.metrics.connectionTime, isNull);
      
      await vpnService.connect(_testSource('key-1'));
      await Future.delayed(Duration.zero);
      expect(vpnService.metrics.connectionTime, isNotNull);

      await vpnService.disconnect();
      await Future.delayed(Duration.zero);
      expect(vpnService.metrics.lastDisconnectedAt, isNotNull);
    });

    test('should provide copyWith for metrics updates', () {
      final original = vpnService.metrics;
      expect(original.totalConnections, 0);
      
      final updated = original.copyWith(totalConnections: 5);
      expect(updated.totalConnections, 5);
      expect(original.totalConnections, 0);
    });
  });
}
