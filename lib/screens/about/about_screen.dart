import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_list_tile.dart';

/// About screen: identity, version and legal links.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.aboutTitle,
      subtitle: AppConstants.appName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nexa VPN',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.appTagline,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => Text(
                    'Version ${snapshot.data?.version ?? AppConstants.appVersion}'
                    ' (${snapshot.data?.buildNumber ?? '1'})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          GlassListTile(
            icon: Icons.privacy_tip_rounded,
            title: l10n.aboutPrivacyPolicy,
            subtitle: l10n.aboutPrivacyHint,
            onTap: () => context.push('/privacy'),
          ),
          GlassListTile(
            icon: Icons.help_center_rounded,
            title: l10n.faqTitle,
            subtitle: l10n.aboutFaqHint,
            onTap: () => context.push('/faq'),
          ),
          GlassListTile(
            icon: Icons.support_agent_rounded,
            title: l10n.profileSupport,
            subtitle: l10n.aboutSupportHint,
            onTap: () => context.push('/support'),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Made with care for your privacy.\n'
              '© 2026 Nexa VPN',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
