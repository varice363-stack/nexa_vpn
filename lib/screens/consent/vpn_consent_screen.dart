import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/consent_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Prominent VpnService disclosure.
///
/// Google Play requires this to be shown inside the app (not only in the
/// store listing or the privacy policy), visible during normal use without
/// digging through menus, and accepted by an affirmative user action.
/// It is shown right after onboarding and before any tunnel can be opened.
class VpnConsentScreen extends ConsumerWidget {
  const VpnConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryBright,
                              AppColors.primaryBright.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.vpn_lock_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.consentTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.consentIntro,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _DisclosureItem(
                        icon: Icons.security_rounded,
                        title: l10n.consentPoint1Title,
                        body: l10n.consentPoint1Body,
                      ),
                      _DisclosureItem(
                        icon: Icons.lock_rounded,
                        title: l10n.consentPoint2Title,
                        body: l10n.consentPoint2Body,
                      ),
                      _DisclosureItem(
                        icon: Icons.visibility_off_rounded,
                        title: l10n.consentPoint3Title,
                        body: l10n.consentPoint3Body,
                      ),
                      _DisclosureItem(
                        icon: Icons.block_rounded,
                        title: l10n.consentPoint4Title,
                        body: l10n.consentPoint4Body,
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/privacy'),
                          child: Text(
                            l10n.consentReadPolicy,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBright,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primaryBright,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  children: [
                    GlassButton(
                      label: l10n.consentAgree,
                      icon: Icons.check_rounded,
                      onTap: () async {
                        await ref.read(vpnConsentProvider.notifier).accept();
                        if (!context.mounted) return;
                        context.go('/');
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.consentRequired)),
                        );
                      },
                      child: Text(
                        l10n.consentDecline,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primaryBright),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
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
