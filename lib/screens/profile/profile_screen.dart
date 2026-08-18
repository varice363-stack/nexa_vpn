import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notifications_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/profile_providers.dart';
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
    final authUser = ref.watch(authProvider).value;
    final profile = ref.watch(profileProvider).value ?? const UserProfile();
    final subscription = ref.watch(subscriptionProvider).value;
    final isPremium = subscription?.isPremium ?? false;
    final sessions = ref.watch(sessionsProvider).value ?? const [];
    final unread = ref.watch(unreadNotificationsProvider);

    return AppPage(
      title: 'Profile',
      subtitle: authUser == null
          ? 'Guest mode'
          : (isPremium ? 'Premium member' : 'Free plan'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity card.
          if (authUser == null)
            _GuestCard(onSignIn: () => context.push('/login'))
          else
            _IdentityCard(
              profile: profile,
              email: authUser.email,
              onEdit: () => _editProfile(context, ref),
            ),
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
          GlassListTile(
            icon: Icons.health_and_safety_rounded,
            title: 'Diagnostics',
            subtitle: 'Run connection checks',
            onTap: () => context.push('/diagnostics'),
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
          const SizedBox(height: 16),
          if (authUser != null)
            Center(
              child: TextButton(
                onPressed: () => _signOut(context, ref),
                child: const Text(
                  'Sign out',
                  style: TextStyle(fontSize: 13, color: AppColors.danger),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider).value ?? const UserProfile();
    final nameController = TextEditingController(text: profile.name);
    final emailController = TextEditingController(text: profile.email);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(profileProvider.notifier).save(
                    name: nameController.text,
                    email: emailController.text,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out. Welcome back anytime.')),
    );
  }
}

/// Guest identity card with a sign-in CTA.
class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sign in to sync devices, keys and subscriptions',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSignIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.email,
    required this.onEdit,
  });

  final UserProfile profile;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Center(
              child: Text(
                profile.initials,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: AppColors.primaryBright,
            ),
          ),
        ],
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
