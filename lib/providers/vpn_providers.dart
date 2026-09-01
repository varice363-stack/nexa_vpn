import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../domain/services/connection_manager.dart';
import '../domain/services/vpn_service.dart';
import '../domain/services/tunnel_manager.dart';
import '../models/app_notification.dart';
import '../models/connection_source.dart';
import '../models/connection_stats.dart';
import '../models/vpn_config.dart';
import '../models/vpn_status.dart';
import '../services/vpn/connection_manager_impl.dart';
import '../services/vpn/vpn_service_impl.dart';
import '../services/vpn/xray_tunnel_manager.dart';
import 'app_providers.dart';
import 'connection_source_providers.dart';
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

/// Selects the tunnel backend.
///
/// Overridden with `MockTunnelManager` in tests and anywhere a real tunnel is
/// impossible; the default is the Xray engine so a normal build connects for
/// real.
final tunnelManagerProvider = Provider<TunnelManager>(
  (ref) => XrayTunnelManager(logger: ref.watch(loggerProvider)),
);

/// The application VPN service.
final vpnServiceProvider = Provider<VpnService>(
  (ref) {
    final service = VpnServiceImpl(
      tunnel: ref.watch(tunnelManagerProvider),
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
                    '${service.activeSource?.label ?? 'selected key'}',
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

  Future<void> connect(ConnectionSource source) =>
      ref.read(vpnServiceProvider).connect(source);

  Future<void> disconnect() => ref.read(vpnServiceProvider).disconnect();

  /// Connects the active key, or disconnects if a tunnel is already up.
  ///
  /// Throws [AppException] when nothing has been added yet — the caller is
  /// expected to send the user to the key screen instead.
  Future<void> toggle([ConnectionSource? source]) async {
    final current = state;
    if (current == VpnStatus.connected || current == VpnStatus.connecting ||
        current == VpnStatus.reconnecting) {
      await disconnect();
      return;
    }
    final target = source ?? ref.read(activeSourceProvider);
    if (target == null) {
      throw const AppException('Add a key before connecting.');
    }
    await connect(target);
  }
}

/// Live session metrics (duration, bytes, speed).
final connectionStatsProvider = StreamProvider<ConnectionStats>(
  (ref) => ref.watch(connectionManagerProvider).stats,
);

/// Живая задержка до сервера, мс. null — замер недоступен.
///
/// Опрашивается раз в 10 секунд и только при поднятом туннеле: до
/// подключения измерять нечего. Раньше на этом месте показывался пинг
/// сервера из демо-каталога, который к активному ключу отношения не имел.
final livePingProvider = StreamProvider<int?>((ref) async* {
  final connected =
      ref.watch(connectionStateProvider) == VpnStatus.connected;
  if (!connected) {
    yield null;
    return;
  }

  final tunnel = ref.watch(tunnelManagerProvider);
  yield await tunnel.measurePing();

  while (true) {
    await Future<void>.delayed(const Duration(seconds: 10));
    yield await tunnel.measurePing();
  }
});
