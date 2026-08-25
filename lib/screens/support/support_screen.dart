import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/static_content.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_list_tile.dart';

/// Support hub: contact channels and FAQ entry point.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.supportTitle,
      subtitle: l10n.supportReplyTime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassListTile(
            icon: Icons.email_rounded,
            title: l10n.supportEmail,
            subtitle: StaticContent.supportEmail,
            trailing: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
            onTap: () async {
              await Clipboard.setData(
                const ClipboardData(text: StaticContent.supportEmail),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.supportEmailCopied)),
              );
            },
          ),
          GlassListTile(
            icon: Icons.send_rounded,
            title: l10n.supportTelegram,
            subtitle: StaticContent.supportTelegram,
            trailing: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
            onTap: () async {
              await Clipboard.setData(
                const ClipboardData(text: StaticContent.supportTelegram),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.supportTelegramCopied)),
              );
            },
          ),
          GlassListTile(
            icon: Icons.help_center_rounded,
            title: 'FAQ',
            subtitle: l10n.aboutFaqHint,
            onTap: () => context.push('/faq'),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.supportStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      l10n.supportOperational,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
