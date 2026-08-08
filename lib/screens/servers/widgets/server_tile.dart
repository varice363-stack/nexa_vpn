import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server.dart';
import '../../../providers/server_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// Glass list item for a server location with favorite + selection states.
class ServerTile extends ConsumerWidget {
  const ServerTile({super.key, required this.server, this.onTap});

  final Server server;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(
      selectedServerProvider.select((selected) => selected?.id == server.id),
    );
    final isFavorite = ref.watch(
      favoritesProvider
          .select((favorites) => favorites.value?.contains(server.id) ?? false),
    );

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: isSelected ? AppColors.primary.withValues(alpha: 0.10) : null,
      borderColor: isSelected
          ? AppColors.primary.withValues(alpha: 0.45)
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Row(
            children: [
              _FlagBox(flag: server.flagEmoji),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            server.country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (server.premium) ...[
                          const SizedBox(width: 6),
                          const _PremiumBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            server.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${server.ping} ms',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _LoadBar(load: server.load),
                  const SizedBox(height: 2),
                  Text(
                    '${server.loadPercent}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () =>
                    ref.read(favoritesProvider.notifier).toggle(server),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: isFavorite
                        ? AppColors.premium
                        : AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              isSelected
                  ? const _SelectedMark()
                  : const Icon(
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
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(flag, style: const TextStyle(fontSize: 25)),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: const BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 11, color: Colors.black87),
          SizedBox(width: 3),
          Text(
            'PRO',
            style: TextStyle(
              fontSize: 8.5,
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

class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.load});

  /// Server load in `0.0 .. 1.0`.
  final double load;

  @override
  Widget build(BuildContext context) {
    final color = load < 0.5
        ? AppColors.success
        : load < 0.8
            ? AppColors.warning
            : AppColors.danger;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 64,
        height: 3.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white.withValues(alpha: 0.08)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: load.clamp(0.03, 1.0).toDouble(),
                child: Container(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
    );
  }
}
