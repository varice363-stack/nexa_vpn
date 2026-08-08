import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/vpn_status.dart';
import '../../providers/server_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/vpn_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/buttons/power_button.dart';
import '../../widgets/common/glass_container.dart';

/// Full-screen connection experience: tunnel status, live metrics,
/// protocol info and disconnect control.
class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final server = ref.watch(selectedServerProvider);
    final stats = ref.watch(connectionStatsProvider).value;
    final settings = ref.watch(settingsProvider).value;

    final isConnected = status == VpnStatus.connected;
    final isBusy =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;

    final buttonState = switch (status) {
      VpnStatus.disconnected => PowerButtonState.disconnected,
      VpnStatus.connecting || VpnStatus.disconnecting =>
        PowerButtonState.connecting,
      VpnStatus.connected => PowerButtonState.connected,
      VpnStatus.error => PowerButtonState.disconnected,
    };

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Connection',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isConnected
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Protected',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  status.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                // Server info.
                GlassContainer(
                  blur: true,
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Text(
                        server?.flagEmoji ?? '🌐',
                        style: const TextStyle(fontSize: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server?.country ?? 'No server selected',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              server == null
                                  ? 'Open Servers to pick a location'
                                  : '${server.city} • ${server.ping} ms • '
                                      '${settings?.protocol.label ?? 'WireGuard'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                const SizedBox(height: 44),
                PowerButton(
                  state: buttonState,
                  size: 210,
                  onTap: isBusy
                      ? null
                      : () {
                          final current = ref.read(selectedServerProvider);
                          if (current == null) return;
                          ref
                              .read(connectionStateProvider.notifier)
                              .toggle(current);
                        },
                ),
                const SizedBox(height: 30),
                // Live metrics.
                Row(
                  children: [
                    _MetricTile(
                      icon: Icons.download_rounded,
                      accent: AppColors.primaryBright,
                      value: isConnected
                          ? Formatters.mbps(stats?.speedDown ?? 0)
                          : '—',
                      label: 'Download',
                    ),
                    const SizedBox(width: 10),
                    _MetricTile(
                      icon: Icons.upload_rounded,
                      accent: AppColors.cyan,
                      value: isConnected
                          ? Formatters.mbps(stats?.speedUp ?? 0)
                          : '—',
                      label: 'Upload',
                    ),
                    const SizedBox(width: 10),
                    _MetricTile(
                      icon: Icons.timer_rounded,
                      accent: AppColors.success,
                      value: isConnected
                          ? Formatters.duration(
                              stats?.duration ?? Duration.zero,
                            )
                          : '00:00',
                      label: 'Session',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lan_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'IP  ${isConnected ? AppConstants.virtualIp : '—'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isConnected
                            ? '${Formatters.bytes(stats?.bytesDown ?? 0)} ↓  '
                                '${Formatters.bytes(stats?.bytesUp ?? 0)} ↑'
                            : 'Waiting for tunnel…',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isConnected)
                  GestureDetector(
                    onTap: () => ref
                        .read(connectionStateProvider.notifier)
                        .disconnect(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.5),
                        ),
                        color: AppColors.danger.withValues(alpha: 0.08),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.power_settings_new_rounded,
                            size: 17,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Disconnect',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
