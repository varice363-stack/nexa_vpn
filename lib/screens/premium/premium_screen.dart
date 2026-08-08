import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/subscription_plan.dart';
import '../../providers/access_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/billing_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/section_header.dart';

/// Premium — plans from the backend, mock checkout, current subscription.
///
/// States: Loading / Loaded / Empty / Error / Offline (static fallback).
/// Guests are prompted to sign in before checkout.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String? _selectedPlanId;
  String? _checkoutError;
  bool _checkingOut = false;

  Future<void> _checkout(SubscriptionPlan plan) async {
    final authUser = ref.read(authProvider).value;
    if (authUser == null) {
      context.push('/login');
      return;
    }
    setState(() {
      _checkingOut = true;
      _checkoutError = null;
    });
    try {
      final result =
          await ref.read(billingRepositoryProvider).createCheckout(plan.id);
      ref.read(loggerProvider).info(
            'Checkout initiated: ${plan.name} (${result.status})',
            source: 'billing',
          );
      if (!mounted) return;
      // Mock checkout: no real payment, simulate a successful activation
      // by refreshing server state (idempotent).
      await ref.read(subscriptionProvider.notifier).refresh();
      await ref.read(accessKeysProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _checkingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout initiated — payment is simulated.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingOut = false;
        _checkoutError = 'Checkout failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).value;
    final plansAsync = ref.watch(plansProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final subscription = subscriptionAsync.value;

    final plans = plansAsync.value ?? const <SubscriptionPlan>[];
    final isPremium = subscription?.isPremium ?? false;
    final offline = plansAsync.hasError && plans.isEmpty;

    // Keep selection valid when plans arrive.
    if (_selectedPlanId == null && plans.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPlanId = plans.first.id);
      });
    }
    final selected = plans.isEmpty
        ? null
        : plans.firstWhere(
            (p) => p.id == _selectedPlanId,
            orElse: () => plans.first,
          );

    return AppPage(
      title: 'Premium',
      subtitle: isPremium
          ? 'Active · ${subscription?.planId ?? 'premium'}'
          : 'Unlock the full Nexa experience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plansAsync.isLoading && plans.isEmpty)
            const _LoadingState()
          else if (offline)
            _OfflineState(
              onRetry: () => ref.read(plansProvider.notifier).refresh(),
            )
          else if (plans.isEmpty)
            const EmptyState(
              icon: Icons.workspace_premium_rounded,
              title: 'No plans available',
              message: 'Check back soon — plans are being prepared.',
            )
          else ...[
            _CurrentSubscriptionCard(
              isPremium: isPremium,
              planName: subscription?.planId,
              expiresAt: subscription?.expiresAt,
              onUpgrade: () => ref.read(plansProvider.notifier).refresh(),
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'CHOOSE YOUR PLAN'),
            for (var i = 0; i < plans.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanCard(
                  plan: plans[i],
                  selected: selected?.id == plans[i].id,
                  onTap: () => setState(() => _selectedPlanId = plans[i].id),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: 120 + i * 90),
                      duration: 350.ms,
                    ),
              ),
            if (_checkoutError != null) ...[
              const SizedBox(height: 4),
              Text(
                _checkoutError!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (authUser == null)
              GlassButton(
                label: 'Sign in to subscribe',
                icon: Icons.login_rounded,
                gradient: AppColors.premiumGradient,
                foreground: Colors.black87,
                onTap: () => context.push('/login'),
              )
            else if (selected != null)
              GlassButton(
                label:
                    'Get Premium — ${selected.priceLabel}${selected.durationDays > 0 ? ' / ${selected.durationLabel}' : ''}',
                icon: Icons.workspace_premium_rounded,
                loading: _checkingOut,
                gradient: AppColors.premiumGradient,
                foreground: Colors.black87,
                onTap: () => _checkout(selected),
              ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Payments are simulated in this build. Store integration planned.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Current subscription card ─────────────────────────────────────────────

class _CurrentSubscriptionCard extends StatelessWidget {
  const _CurrentSubscriptionCard({
    required this.isPremium,
    required this.planName,
    required this.expiresAt,
    required this.onUpgrade,
  });

  final bool isPremium;
  final String? planName;
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
      borderColor:
          isPremium ? AppColors.premium.withValues(alpha: 0.35) : null,
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
                          ? _expiryText(planName, expiresAt)
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
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
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

  String _expiryText(String? plan, DateTime? expiresAt) {
    final planLabel =
        plan == null ? 'Premium' : '${plan[0]}${plan.substring(1).toLowerCase()}';
    if (expiresAt == null) return '$planLabel · Lifetime';
    return '$planLabel · expires ${Formatters.shortDate(expiresAt)}';
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBest = plan.code == 'YEARLY';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.premiumGradient,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.description ?? plan.durationLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${plan.durationDays} days of access',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.priceLabel,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '/ ${plan.durationLabel}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppColors.primaryGradient : null,
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────

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
            'Loading plans…',
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
          'Cannot reach the server. Plans will appear once the connection '
          'is back.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
