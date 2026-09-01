import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/connection_source_providers.dart';
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
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(connectionStateProvider);
    final stats = ref.watch(connectionStatsProvider).value;

    final PowerButtonState buttonState = switch (status) {
      VpnStatus.disconnected => PowerButtonState.disconnected,
      VpnStatus.connecting || VpnStatus.disconnecting =>
        PowerButtonState.connecting,
      VpnStatus.reconnecting => PowerButtonState.connecting,
      VpnStatus.connected => PowerButtonState.connected,
      VpnStatus.error => PowerButtonState.disconnected,
    };

    final (statusColor, statusText) = switch (status) {
      VpnStatus.disconnected => (AppColors.textSecondary, l10n.powerNotConnected),
      VpnStatus.connecting => (AppColors.warning, l10n.powerConnecting),
      VpnStatus.connected => (
          AppColors.success,
          'Connected • ${Formatters.duration(stats?.duration ?? Duration.zero)}',
        ),
      VpnStatus.disconnecting => (AppColors.warning, l10n.powerDisconnecting),
      VpnStatus.reconnecting => (AppColors.warning, l10n.powerReconnecting),
      VpnStatus.error => (AppColors.danger, l10n.powerConnectionError),
    };

    return Column(
      children: [
        PowerButton(
          state: buttonState,
          onTap: () {
            // No account gate here on purpose: a key the user already owns
            // must work on first launch, before any sign-up. Requiring an
            // account to connect would close the door the product depends on.
            final source = ref.read(activeSourceProvider);
            if (source == null) {
              // Nothing to connect with yet — send them where keys are added.
              context.push('/key');
              return;
            }
            ref.read(connectionStateProvider.notifier).toggle(source);
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
          (status == VpnStatus.connected || status == VpnStatus.reconnecting)
              ? l10n.powerTapToDisconnect
              : l10n.powerTapToConnect,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
