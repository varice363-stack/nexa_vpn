import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/datasources/static_content.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_button.dart';

/// URL of the full HTML privacy policy hosted on GitHub Pages.
/// Keep this in sync with the GitHub Pages publishing configuration.
const String kPrivacyPolicyUrl =
    'https://varice363-stack.github.io/nexa_vpn/privacy/';

/// Privacy policy (static in-app summary) with a link to the full HTML version.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.privacyPolicyTitle,
      subtitle: l10n.privacyLastUpdated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Short notice directing users to the full policy.
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withValues(alpha: 0.06),
            borderColor: AppColors.primary.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.privacyFullPolicyNotice,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: l10n.privacyOpenFullPolicy,
                  icon: Icons.open_in_new_rounded,
                  onTap: () async {
                    final uri = Uri.parse(kPrivacyPolicyUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
          for (final (title, body) in StaticContent.privacySections)
            GlassContainer(
              borderRadius: BorderRadius.circular(18),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
