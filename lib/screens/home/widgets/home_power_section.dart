import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/server_providers.dart';
import '../../../providers/vpn_providers.dart';
import '../../../theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/buttons/power_button.dart';
import '../../../core/utils/formatters.dart';

/// Connection control driven by the real VPN service state.
class HomePowerSection extends ConsumerWidget {
  const HomePowerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final stats = ref.watch(connectionStatsProvider).value;

    final PowerButtonState buttonState = switch (status) {
      VpnStatus.disconnected => PowerButtonState.disconnected,
      VpnStatus.connecting || VpnStatus.disconnecting =>
        PowerButtonState.connecting,
      VpnStatus.connected => PowerButtonState.connected,
      VpnStatus.error => PowerButtonState.disconnected,
    };

    final (statusColor, statusText) = switch (status) {
      VpnStatus.disconnected => (AppColors.textSecondary, 'Not connected'),
      VpnStatus.connecting => (AppColors.warning, 'Connecting…'),
      VpnStatus.connected => (
          AppColors.success,
          'Connected • ${Formatters.duration(stats?.duration ?? Duration.zero)}',
        ),
      VpnStatus.disconnecting => (AppColors.warning, 'Disconnecting…'),
      VpnStatus.error => (AppColors.danger, 'Connection error'),
    };

    return Column(
      children: [
        PowerButton(
          state: buttonState,
          onTap: () {
            // Guest Mode: connecting requires an account.
            if (ref.read(authProvider).value == null) {
              context.go('/login');
              return;
            }
            final server = ref.read(selectedServerProvider);
            if (server == null) return;
            ref.read(connectionStateProvider.notifier).toggle(server);
          },
        ),
        const SizedBox(height: 18),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status == VpnStatus.connected ? 'Tap to disconnect' : 'Tap to connect',
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
