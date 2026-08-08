import 'package:flutter/material.dart';
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
    return AppPage(
      title: 'Support',
      subtitle: 'We usually reply within 24 hours',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassListTile(
            icon: Icons.email_rounded,
            title: 'Email support',
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
                const SnackBar(content: Text('Email address copied')),
              );
            },
          ),
          GlassListTile(
            icon: Icons.send_rounded,
            title: 'Telegram',
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
                const SnackBar(content: Text('Telegram handle copied')),
              );
            },
          ),
          GlassListTile(
            icon: Icons.help_center_rounded,
            title: 'FAQ',
            subtitle: 'Answers to common questions',
            onTap: () => context.push('/faq'),
          ),
          GlassListTile(
            icon: Icons.feedback_rounded,
            title: 'Leave feedback',
            subtitle: 'Share your experience',
            onTap: () => context.push('/feedback'),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: AppColors.success),
                    SizedBox(width: 8),
                    Text(
                      'All systems operational',
                      style: TextStyle(
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
