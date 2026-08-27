import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/admin_providers.dart';
import '../../providers/identity_providers.dart';
import '../../providers/notifications_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/error_display.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_list_tile.dart';
import '../../widgets/common/section_header.dart';

/// Profile hub: identity (authenticated or guest), plan, quick access.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final subscription = subscriptionAsync.value;
    final isPremium = subscription?.isPremium ?? false;
    final unread = ref.watch(unreadNotificationsProvider);

    // Если загрузка подписки упала с ошибкой — покажем понятное сообщение.
    if (subscriptionAsync.hasError && subscription == null) {
      return AppPage(
        title: l10n.profileTitle,
        subtitle: l10n.commonFreePlan,
        child: ErrorDisplay(
          message: l10n.profileLoadError,
          onRetry: () => ref.read(subscriptionProvider.notifier).refresh(),
        ),
      );
    }

    return AppPage(
      title: l10n.profileTitle,
      subtitle: isPremium ? l10n.profilePremiumMember : l10n.commonFreePlan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Код устройства вместо аккаунта: почты и пароля больше нет.
          _IdentityCodeCard(
            title: l10n.profileMyCode,
            onTap: () => context.push('/identity'),
          ),
          const SizedBox(height: 16),
          // Plan card.
          _PlanCard(
            isPremium: isPremium,
            planName: isPremium ? l10n.profileNexaPremium : l10n.commonFreePlan,
            planDescription: isPremium
                ? l10n.profileAllUnlocked
                : l10n.profileUpgradeHint,
            onTap: () => context.push('/premium'),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: l10n.profileAccount),
          GlassListTile(
            icon: Icons.receipt_long_rounded,
            title: l10n.profilePaymentHistory,
            subtitle: l10n.profilePaymentHistoryHint,
            onTap: () => context.push('/payment-history'),
          ),
          GlassListTile(
            icon: Icons.notifications_rounded,
            title: l10n.notificationsTitle,
            subtitle: l10n.profileNotificationsHint,
            badge: unread > 0 ? '$unread' : null,
            onTap: () => context.push('/notifications'),
          ),
          GlassListTile(
            icon: Icons.settings_rounded,
            title: l10n.profileSettings,
            subtitle: l10n.profileSettingsHint,
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: l10n.profileSupport.toUpperCase()),
          GlassListTile(
            icon: Icons.support_agent_rounded,
            title: l10n.profileSupport,
            subtitle: l10n.profileSupportHint,
            onTap: () => context.push('/support'),
          ),
          GlassListTile(
            icon: Icons.info_rounded,
            title: l10n.profileAbout,
            subtitle: l10n.profileAboutHint,
            onTap: () => context.push('/about'),
          ),
          // Раздел владельца. Виден, только если код этого устройства
          // совпадает с кодом, заданным при сборке (--dart-define=OWNER_CODE).
          // Обычный человек не должен даже знать, что выпуск ключей есть.
          if (ref.watch(adminUnlockedProvider)) ...[
            const SizedBox(height: 20),
            SectionHeader(title: l10n.adminOwnerSection),
            GlassListTile(
              icon: Icons.dashboard_rounded,
              title: l10n.adminDashboard,
              subtitle: l10n.adminDashboardSubtitle,
              onTap: () => context.push('/admin/dashboard'),
            ),
            GlassListTile(
              icon: Icons.vpn_key_rounded,
              title: l10n.adminKeyIssue,
              subtitle: l10n.adminKeyIssueHint,
              onTap: () => context.push('/admin/keys'),
            ),
          ],
        ],
      ),
    );
  }

}

/// Guest identity card with a sign-in CTA.
/// Карточка кода устройства — то, что заменило блок аккаунта.
///
/// Показывает не сам код целиком, а лишь первую группу: полный код живёт
/// на отдельном экране, чтобы его нельзя было подсмотреть мельком через
/// плечо.
class _IdentityCodeCard extends ConsumerWidget {
  const _IdentityCodeCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(identityProvider).value;
    final masked = code == null
        ? '…'
        : '${code.split('-').take(2).join('-')}-••••-••••-••••';

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.vpn_key_rounded,
                  size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    masked,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.isPremium,
    required this.planName,
    required this.planDescription,
    required this.onTap,
  });

  final bool isPremium;
  final String planName;
  final String planDescription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        color: isPremium ? AppColors.premium.withValues(alpha: 0.08) : null,
        borderColor: isPremium
            ? AppColors.premium.withValues(alpha: 0.4)
            : null,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isPremium
                    ? AppColors.premiumGradient
                    : AppColors.primaryGradient,
              ),
              child: Icon(
                isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_open_rounded,
                size: 20,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    planDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}


