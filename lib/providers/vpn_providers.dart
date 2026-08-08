import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/connection_manager.dart';
import '../domain/services/vpn_service.dart';
import '../models/app_notification.dart';
import '../models/connection_stats.dart';
import '../models/server.dart';
import '../models/vpn_config.dart';
import '../models/vpn_status.dart';
import '../services/vpn/connection_manager_impl.dart';
import '../services/vpn/tunnel_manager_impl.dart';
import '../services/vpn/vpn_service_impl.dart';
import 'app_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

/// Tracks the live session and persists history.
final connectionManagerProvider = Provider<ConnectionManager>(
  (ref) {
    final manager = ConnectionManagerImpl(logger: ref.watch(loggerProvider));
    ref.onDispose(manager.dispose);
    return manager;
  },
);

/// The application VPN service. Replace `MockTunnelManager` with the native
/// implementation here — single integration point.
final vpnServiceProvider = Provider<VpnService>(
  (ref) {
    final service = VpnServiceImpl(
      tunnel: MockTunnelManager(),
      configProvider: () =>
          ref.read(settingsProvider).value?.vpnConfig ??
          const VpnConfig(),
      logger: ref.watch(loggerProvider),
    )..init();
    ref
        .watch(connectionManagerProvider)
        .bind(service, ref.watch(sessionManagerProvider));
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Connection status, reactive across the app.
final connectionStateProvider =
    NotifierProvider<ConnectionNotifier, VpnStatus>(ConnectionNotifier.new);

class ConnectionNotifier extends Notifier<VpnStatus> {
  StreamSubscription<VpnStatus>? _sub;

  @override
  VpnStatus build() {
    final service = ref.watch(vpnServiceProvider);
    _sub = service.statuses.listen((status) {
      state = status;
      if (status == VpnStatus.connected) {
        final notificationsEnabled =
            ref.read(settingsProvider).value?.notificationsEnabled ??
                true;
        if (notificationsEnabled) {
          ref.read(notificationServiceProvider).push(
                title: 'Connected',
                body: 'Tunnel is active via '
                    '${service.activeServer?.displayName ?? 'selected server'}',
                icon: AppNotificationIcon.connection,
              );
        }
        ref.invalidate(sessionsProvider);
      }
      if (status == VpnStatus.disconnected) {
        ref.invalidate(sessionsProvider);
      }
    });
    ref.onDispose(() => _sub?.cancel());
    return service.status;
  }

  Future<void> connect(Server server) =>
      ref.read(vpnServiceProvider).connect(server);

  Future<void> disconnect() => ref.read(vpnServiceProvider).disconnect();

  Future<void> toggle(Server server) async {
    final current = state;
    if (current == VpnStatus.connected || current == VpnStatus.connecting) {
      await disconnect();
    } else {
      await connect(server);
    }
  }
}

/// Live session metrics (duration, bytes, speed).
final connectionStatsProvider = StreamProvider<ConnectionStats>(
  (ref) => ref.watch(connectionManagerProvider).stats,
);
