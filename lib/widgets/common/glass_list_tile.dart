import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'glass_container.dart';

/// Glass list row with leading icon, title, optional subtitle and trailing.
class GlassListTile extends StatelessWidget {
  const GlassListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: AppColors.primaryBright),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
      ),
    );
  }
}
