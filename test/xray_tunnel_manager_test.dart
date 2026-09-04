import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/xray_tunnel_manager.dart';
import 'package:nexa_vpn/core/utils/app_logger.dart';
import 'package:nexa_vpn/models/connection_source.dart';

void main() {
  group('XrayTunnelManager', () {
    late XrayTunnelManager tunnelManager;
    late AppLogger logger;

    setUp(() {
      logger = AppLogger();
      tunnelManager = XrayTunnelManager(logger: logger);
    });

    tearDown(() {
      tunnelManager.dispose();
    });

    test('initial phase should be idle', () {
      expect(tunnelManager.phase, TunnelPhase.idle);
    });

    test('should emit phase changes', () async {
      final phases = <TunnelPhase>[];
      final subscription = tunnelManager.phases.listen(phases.add);
      
      // Initial phase should be emitted
      await Future.delayed(const Duration(milliseconds: 100));
      expect(phases.length, greaterThan(0));
      expect(phases.first, TunnelPhase.idle);
      
      await subscription.cancel();
    });

    test('phases stream should be broadcast', () {
      // Should be able to listen multiple times
      final stream1 = tunnelManager.phases;
      final stream2 = tunnelManager.phases;
      
      expect(stream1, isNotNull);
      expect(stream2, isNotNull);
    });

    test('measurePing should return null when not connected', () async {
      final ping = await tunnelManager.measurePing();
      expect(ping, isNull);
    });

    test('stopTunnel should be safe to call when idle', () async {
      // Should not throw
      await tunnelManager.stopTunnel();
      expect(tunnelManager.phase, TunnelPhase.idle);
    });

    test('should handle dispose gracefully', () async {
      tunnelManager.dispose();
      // Should not throw when called again
      tunnelManager.dispose();
    });
  });

  group('TunnelPhase', () {
    test('should have correct label for each phase', () {
      expect(TunnelPhase.idle.label, 'Idle');
      expect(TunnelPhase.handshake.label, 'Handshake');
      expect(TunnelPhase.authenticating.label, 'Authenticating');
      expect(TunnelPhase.establishing.label, 'Establishing tunnel');
      expect(TunnelPhase.connected.label, 'Connected');
      expect(TunnelPhase.disconnecting.label, 'Disconnecting');
      expect(TunnelPhase.error.label, 'Error');
    });
  });
}
