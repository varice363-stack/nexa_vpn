import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/access_key.dart';
import '../../providers/access_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/section_header.dart';
import 'widgets/vless_config_panel.dart';

/// "My Access" — the commercial core surface: subscription status,
/// access keys, device usage.
///
/// UI states: Loading / Empty / Active / Expired / Offline.
class MyAccessScreen extends ConsumerWidget {
  const MyAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final keysAsync = ref.watch(accessKeysProvider);
    final subscription = subscriptionAsync.value;
    final keys = keysAsync.value ?? const <AccessKey>[];
    final deviceCount = ref.watch(deviceCountProvider);

    final isPremium = subscription?.isPremium ?? false;
    final keysLoading = keysAsync.isLoading && keys.isEmpty;
    final subLoading = subscriptionAsync.isLoading && subscription == null;

    // Offline: API unreachable and nothing cached.
    final offline =
        keysAsync.hasError && !keysAsync.isLoading && keys.isEmpty &&
            subscriptionAsync.hasError && subscription == null;

    return AppPage(
      title: 'My Access',
      subtitle: isPremium ? 'Premium access' : 'No active plan',
      child: offline
          ? _OfflineState(
              onRetry: () {
                ref.read(accessKeysProvider.notifier).refresh();
                ref.read(subscriptionProvider.notifier).refresh();
              },
            )
          : (subLoading || keysLoading)
              ? const _LoadingState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Subscription status card ────────────────────────
                    _SubscriptionCard(
                      isPremium: isPremium,
                      plan: subscription?.planId,
                      expiresAt: subscription?.expiresAt,
                      onUpgrade: () => context.push('/premium'),
                    ),
                    const SizedBox(height: 18),
                    // ── Stats ───────────────────────────────────────────
                    Row(
                      children: [
                        _StatTile(
                          icon: Icons.vpn_key_rounded,
                          accent: AppColors.primaryBright,
                          value: '${keys.length}',
                          label: 'Keys',
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          icon: Icons.devices_rounded,
                          accent: AppColors.cyan,
                          value: '$deviceCount',
                          label: 'Devices',
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          icon: Icons.workspace_premium_rounded,
                          accent: AppColors.premium,
                          value: isPremium ? 'ON' : 'OFF',
                          label: 'Premium',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'ACCESS KEYS'),
                    // ── No active access banner ─────────────────────────
                    if (keys.isNotEmpty && !keys.any((k) => k.isActive)) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassContainer(
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          color: AppColors.warning.withValues(alpha: 0.08),
                          borderColor:
                              AppColors.warning.withValues(alpha: 0.3),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No active access — renew your subscription '
                                  'to activate a key.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // ── Active key configuration (VLESS) ──────────────
                    if (keys.any((k) => k.isActive)) ...[
                      for (final key in keys.where((k) => k.isActive))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: VlessConfigPanel(key_: key),
                        ),
                    ],
                    // ── Keys / empty ────────────────────────────────────
                    if (keys.isEmpty)
                      EmptyState(
                        icon: Icons.vpn_key_off_rounded,
                        title: 'No access keys yet',
                        message:
                            'Get access to generate your personal key — '
                            'usable in the Nexa app and any compatible client.',
                        actionLabel: 'Get access',
                        onAction: () => context.push('/premium'),
                      )
                    else
                      for (var i = 0; i < keys.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _KeyCard(accessKey: keys[i]).animate().fadeIn(
                                begin: 0,
                                delay: Duration(milliseconds: 80 + i * 70),
                                duration: 300.ms,
                              ),
                        ),
                  ],
                ),
    );
  }
}

// ── Subscription card ──────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.isPremium,
    required this.plan,
    required this.expiresAt,
    required this.onUpgrade,
  });

  final bool isPremium;
  final String? plan;
  final DateTime? expiresAt;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final daysLeft = expiresAt?.difference(DateTime.now()).inDays;

    return GlassContainer(
      blur: true,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      color: isPremium ? AppColors.premium.withValues(alpha: 0.07) : null,
      borderColor: isPremium
          ? AppColors.premium.withValues(alpha: 0.35)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      isPremium ? 'Premium active' : 'Free plan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? _expiryLabel(plan, expiresAt, daysLeft)
                          : 'Subscribe to generate access keys',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPremium)
                GestureDetector(
                  onTap: onUpgrade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.premiumGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isPremium && daysLeft != null && daysLeft <= 7) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                daysLeft <= 0
                    ? 'Your subscription has expired — renew to keep access.'
                    : 'Subscription expires in $daysLeft '
                        '${daysLeft == 1 ? 'day' : 'days'} — renew soon.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _expiryLabel(String? plan, DateTime? expiresAt, int? daysLeft) {
    final planLabel = plan == null ? 'Premium' : '${plan[0]}${plan.substring(1).toLowerCase()}';
    if (expiresAt == null) return '$planLabel · Lifetime';
    return '$planLabel · expires ${Formatters.shortDate(expiresAt)}'
        '${daysLeft != null ? ' ($daysLeft d)' : ''}';
  }
}

// ── Key card ──────────────────────────────────────────────────────────────

class _KeyCard extends StatelessWidget {
  const _KeyCard({required this.accessKey});

  final AccessKey accessKey;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (accessKey.status) {
      'ACTIVE' => (AppColors.success, 'ACTIVE'),
      'EXPIRED' => (AppColors.warning, 'EXPIRED'),
      _ => (AppColors.danger, 'REVOKED'),
    };

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      color: accessKey.isActive ? AppColors.success.withValues(alpha: 0.05) : null,
      borderColor: accessKey.isActive
          ? AppColors.success.withValues(alpha: 0.25)
          : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              accessKey.isActive
                  ? Icons.vpn_key_rounded
                  : Icons.vpn_key_off_rounded,
              size: 19,
              color: statusColor,
            ),
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
                        accessKey.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _meta(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            accessKey.protocol,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _meta() {
    final parts = <String>[
      if (accessKey.lastUsedAt != null)
        'last used ${Formatters.shortDate(accessKey.lastUsedAt!)}',
      if (accessKey.expiresAt != null)
        'expires ${Formatters.shortDate(accessKey.expiresAt!)}',
      '${accessKey.deviceCount} ${accessKey.deviceCount == 1 ? 'device' : 'devices'}',
    ];
    return parts.join(' · ');
  }
}

// ── States ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 14),
          Text(
            'Loading your access…',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Offline',
      message:
          'Cannot reach the server. Your access data will appear once the '
          'connection is back.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
