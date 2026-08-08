import 'package:flutter/material.dart';

import '../../models/server.dart';
import '../../theme/app_colors.dart';
import '../common/glass_container.dart';

/// Compact summary of a [Server] — used for the "current server" surface
/// on Home and as the pinned card at the top of the servers list.
class ServerCard extends StatelessWidget {
  const ServerCard({
    super.key,
    required this.server,
    this.onTap,
    this.trailing,
  });

  final Server server;
  final VoidCallback? onTap;

  /// Optional widget rendered on the right edge (e.g. a chevron).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Row(
            children: [
              _FlagBox(flag: server.flagEmoji),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${server.city} • ${server.ping} ms',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (server.premium) ...[
                const _PremiumMark(),
                const SizedBox(width: 10),
              ],
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagBox extends StatelessWidget {
  const _FlagBox({required this.flag});

  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(flag, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _PremiumMark extends StatelessWidget {
  const _PremiumMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.black87),
          SizedBox(width: 3),
          Text(
            'PRO',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
