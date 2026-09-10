import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/connection_source_providers.dart';
import '../../../providers/vpn_providers.dart';
import '../../../theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/buttons/power_button.dart';
import '../../../core/utils/formatters.dart';

/// Секция управления подключением.
///
/// Красивая кнопка питания + статус подключения.
class HomePowerSection extends ConsumerWidget {
  const HomePowerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(connectionStateProvider);
    final stats = ref.watch(connectionStatsProvider).value;
    final source = ref.watch(activeSourceProvider);

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
      VpnStatus.connecting => (const Color(0xFF6C63FF), l10n.powerConnecting),
      VpnStatus.connected => (
          const Color(0xFF22D3EE),
          'Подключено • ${Formatters.duration(stats?.duration ?? Duration.zero)}',
        ),
      VpnStatus.disconnecting => (const Color(0xFF6C63FF), l10n.powerDisconnecting),
      VpnStatus.reconnecting => (const Color(0xFF6C63FF), l10n.powerReconnecting),
      VpnStatus.error => (AppColors.danger, l10n.powerConnectionError),
    };

    return Column(
      children: [
        Semantics(
          label: status == VpnStatus.connected
              ? 'VPN подключено. Нажмите чтобы отключиться'
              : 'VPN отключено. Нажмите чтобы подключиться',
          hint: 'Управление VPN соединением',
          child: PowerButton(
            state: buttonState,
            size: 180,
            onTap: () async {
              final source = ref.read(activeSourceProvider);
              if (source == null) {
                context.push('/key');
                return;
              }

              try {
                await ref.read(connectionStateProvider.notifier).toggle(source);

                if (context.mounted) {
                  final status = ref.read(connectionStateProvider);
                  if (status == VpnStatus.connected) {
                    HapticFeedback.mediumImpact();
                  } else if (status == VpnStatus.disconnected) {
                    HapticFeedback.lightImpact();
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  HapticFeedback.heavyImpact();
                }
              }
            },
          ),
        ),
        const SizedBox(height: 60), // Отступ от текста кнопки
        // Статус подключения
        Text(
          statusText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ).animate().fadeIn(duration: 300.ms),

        if (status == VpnStatus.connecting || status == VpnStatus.reconnecting) ...[
          const SizedBox(height: 10),
          Text(
            l10n.serverConnectingTo(source?.label ?? 'server'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
