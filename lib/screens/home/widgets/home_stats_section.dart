import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// Live download / upload / ping tiles fed by [ConnectionManager].
class HomeStatsSection extends ConsumerWidget {
  const HomeStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(connectionStatsProvider).value;
    final connected =
        ref.watch(connectionStateProvider) == VpnStatus.connected;

    final download =
        connected && stats != null ? '${stats.speedDown.round()} Mbps' : '—';
    final upload =
        connected && stats != null ? '${stats.speedUp.round()} Mbps' : '—';
    // Живой замер через поднятый туннель (Xray probe до generate_204).
    // Пока туннель не поднят или замер не удался — прочерк, а не число
    // из демо-каталога, как было раньше.
    final pingMs = ref.watch(livePingProvider).value;
    final ping = pingMs == null ? '—' : '$pingMs ms';

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.download_rounded,
            accent: AppColors.primaryBright,
            value: download,
            label: l10n.statsDownload,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.upload_rounded,
            accent: AppColors.cyan,
            value: upload,
            label: l10n.statsUpload,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.bolt_rounded,
            accent: AppColors.success,
            value: ping,
            label: l10n.statsPing,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
