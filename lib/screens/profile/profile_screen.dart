import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/admin_providers.dart';
import '../../providers/identity_providers.dart';
import '../../providers/notifications_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_list_tile.dart';
import '../../widgets/common/section_header.dart';

/// Profile hub: identity (authenticated or guest), plan, quick access.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider).value;
    final isPremium = subscription?.isPremium ?? false;
    final sessions = ref.watch(sessionsProvider).value ?? const [];
    final unread = ref.watch(unreadNotificationsProvider);

    return AppPage(
      title: 'Profile',
      subtitle: isPremium ? 'Premium member' : 'Free plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Код устройства вместо аккаунта: почты и пароля больше нет.
          _IdentityCodeCard(onTap: () => context.push('/identity')),
          const SizedBox(height: 16),
          // Plan card.
          _PlanCard(
            isPremium: isPremium,
            planName: isPremium ? 'Nexa Premium' : 'Free Plan',
            onTap: () => context.push('/premium'),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'MY ACTIVITY'),
          Row(
            children: [
              _MiniStat(value: '${sessions.length}', label: 'Sessions'),
              const SizedBox(width: 10),
              _MiniStat(
                value:
                    '${sessions.fold<int>(0, (s, x) => s + x.duration.inMinutes) ~/ 60}h',
                label: 'Online',
              ),
              const SizedBox(width: 10),
              _MiniStat(
                value: isPremium ? '∞' : '1',
                label: 'Devices',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'ACCOUNT'),
          GlassListTile(
            icon: Icons.vpn_key_rounded,
            title: 'My Access',
            subtitle: 'Subscription and access keys',
            onTap: () => context.push('/access'),
          ),
          GlassListTile(
            icon: Icons.receipt_long_rounded,
            title: 'Payment History',
            subtitle: 'Checkouts and payments',
            onTap: () => context.push('/payment-history'),
          ),
          GlassListTile(
            icon: Icons.star_rounded,
            title: 'Favorites',
            subtitle: 'Saved locations',
            onTap: () => context.push('/favorites'),
          ),
          GlassListTile(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'App events and alerts',
            badge: unread > 0 ? '$unread' : null,
            onTap: () => context.push('/notifications'),
          ),
          GlassListTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Protocol, kill switch, DNS',
            onTap: () => context.push('/settings'),
          ),
          GlassListTile(
            icon: Icons.article_rounded,
            title: 'Logs',
            subtitle: 'Diagnostic event log',
            onTap: () => context.push('/logs'),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'SUPPORT'),
          GlassListTile(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            subtitle: 'Contact us or read the FAQ',
            onTap: () => context.push('/support'),
          ),
          GlassListTile(
            icon: Icons.info_rounded,
            title: 'About',
            subtitle: 'Version and legal',
            onTap: () => context.push('/about'),
          ),
          // Раздел владельца. Виден, только если код этого устройства
          // совпадает с кодом, заданным при сборке (--dart-define=OWNER_CODE).
          // Обычный человек не должен даже знать, что выпуск ключей есть.
          if (ref.watch(adminUnlockedProvider)) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'ВЛАДЕЛЕЦ'),
            GlassListTile(
              icon: Icons.vpn_key_rounded,
              title: 'Выпуск ключей',
              subtitle: 'Создать коды на продажу и посмотреть все ключи',
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
  const _IdentityCodeCard({required this.onTap});

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
                  const Text(
                    'Мой код',
                    style: TextStyle(
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
    required this.onTap,
  });

  final bool isPremium;
  final String planName;
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
                    isPremium
                        ? 'All features unlocked'
                        : 'Upgrade for unlimited data and 4K streaming',
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
