import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/vpn_service_impl.dart';
import 'package:nexa_vpn/domain/services/tunnel_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';

/// Mock tunnel manager that emits phase changes via a broadcast stream,
/// matching the behaviour VpnServiceImpl.init() subscribes to.
class MockTunnelManager implements TunnelManager {
  bool shouldFail = false;
  int startCallCount = 0;
  int stopCallCount = 0;

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
    startCallCount++;
    if (shouldFail) {
      _setPhase(TunnelPhase.error);
      throw Exception('Mock tunnel error');
    }
    _setPhase(TunnelPhase.handshake);
    _setPhase(TunnelPhase.connected);
  }

  @override
  Future<void> stopTunnel() async {
    stopCallCount++;
    _setPhase(TunnelPhase.idle);
  }

  @override
  Future<int?> measurePing() async => 50;

  void dispose() => _controller.close();
}

ConnectionSource _testSource(String id, [String label = 'Test Server']) {
  return ConnectionSource(
    id: id,
    label: label,
    uri: 'vless://test@example.com:443',
    origin: ConnectionOrigin.imported,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      vpnService.init();
    });

    tearDown(() {
      vpnService.dispose();
      mockTunnel.dispose();
    });

    test('initial status should be disconnected', () {
      expect(vpnService.status, VpnStatus.disconnected);
    });

    test('connect should call tunnel.startTunnel', () async {
      final source = _testSource('test-key');
      await vpnService.connect(source);
      // Allow stream events to propagate
      await Future.delayed(Duration.zero);
      expect(mockTunnel.startCallCount, 1);
    });

    test('disconnect should call tunnel.stopTunnel', () async {
      final source = _testSource('test-key');
      await vpnService.connect(source);
      await Future.delayed(Duration.zero);
      expect(vpnService.status, VpnStatus.connected);

      await vpnService.disconnect();
      await Future.delayed(Duration.zero);
      expect(mockTunnel.stopCallCount, 1);
    });

    test('metrics should track connection time', () async {
      final source = _testSource('test-key');
      await vpnService.connect(source);
      await Future.delayed(Duration.zero);

      expect(vpnService.metrics.connectionTime, isNotNull);
      expect(vpnService.metrics.totalConnections, 1);
    });

    test('metrics should track disconnection', () async {
      final source = _testSource('test-key');
      await vpnService.connect(source);
      await Future.delayed(Duration.zero);

      await vpnService.disconnect();
      await Future.delayed(Duration.zero);

      expect(vpnService.metrics.totalDisconnections, 1);
      expect(vpnService.metrics.lastDisconnectedAt, isNotNull);
    });

    test('metrics should reset reconnect count on successful connection',
        () async {
      final source = _testSource('test-key');
      await vpnService.connect(source);
      await Future.delayed(Duration.zero);

      expect(vpnService.metrics.reconnectCount, 0);
    });

    test('connect should throw when tunnel fails', () async {
      mockTunnel.shouldFail = true;
      final source = _testSource('test-key');

      expect(
        () => vpnService.connect(source),
        throwsA(isA<Exception>()),
      );
    });

    test('should not connect if already connected to same source', () async {
      final source = _testSource('test-key');
      await vpnService.connect(source);
      await Future.delayed(Duration.zero);
      expect(vpnService.status, VpnStatus.connected);

      await vpnService.connect(source);
      await Future.delayed(Duration.zero);

      expect(mockTunnel.startCallCount, 1);
    });

    test('connecting to different source replaces active source', () async {
      final source1 = _testSource('test-key-1', 'Test Server 1');
      final source2 = _testSource('test-key-2', 'Test Server 2');

      await vpnService.connect(source1);
      await Future.delayed(Duration.zero);
      expect(vpnService.status, VpnStatus.connected);
      expect(vpnService.activeSource?.id, 'test-key-1');

      // Connect to different source — the service starts the new tunnel
      // directly without explicitly stopping the old one first (the tunnel
      // layer handles replacement internally).
      await vpnService.connect(source2);
      await Future.delayed(Duration.zero);

      expect(mockTunnel.startCallCount, 2);
      expect(vpnService.activeSource?.id, 'test-key-2');
      expect(vpnService.status, VpnStatus.connected);
    });
  });
}
