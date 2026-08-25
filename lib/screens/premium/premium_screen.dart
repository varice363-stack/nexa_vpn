import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/formatters.dart';
import '../../models/checkout_result.dart';
import '../../models/subscription_plan.dart';
import '../../models/trial_status.dart';
import '../../providers/access_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/billing_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/section_header.dart';
import 'widgets/premium_banner_section.dart';

/// Premium — тарифы с backend, оформление подписки, текущая подписка.
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

  /// Pending checkout awaiting the mock payment confirmation.
  CheckoutResult? _pendingCheckout;
  bool _paying = false;
  bool _paymentSuccess = false;

  Future<void> _checkout(SubscriptionPlan plan) async {
    // Аккаунт для покупки больше не нужен: доступ выдаётся на код
    // устройства, а не на почту с паролем.
    setState(() {
      _checkingOut = true;
      _checkoutError = null;
      _paymentSuccess = false;
      _pendingCheckout = null;
    });
    try {
      final result =
          await ref.read(billingRepositoryProvider).createCheckout(plan.id);
      ref.read(loggerProvider).info(
            'Checkout initiated: ${plan.name} (${result.status})',
            source: 'billing',
          );
      if (!mounted) return;
      setState(() {
        _checkingOut = false;
        _pendingCheckout = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingOut = false;
        _checkoutError = 'Checkout failed: $e';
      });
    }
  }

  /// GET /billing/transactions/:id — server-side status check after the
  /// user returns from the hosted checkout (source of truth = backend).
  Future<void> _checkPaymentStatus() async {
    final checkout = _pendingCheckout;
    if (checkout == null) return;
    setState(() {
      _paying = true;
      _checkoutError = null;
    });
    try {
      final transaction = await ref
          .read(billingRepositoryProvider)
          .getTransaction(checkout.transactionId);
      if (!mounted) return;
      if (transaction.status == 'PAID') {
        setState(() {
          _paying = false;
          _paymentSuccess = true;
          _pendingCheckout = null;
        });
        await ref.read(subscriptionProvider.notifier).refresh();
        await ref.read(accessKeysProvider.notifier).refresh();
        if (!mounted) return;
        context.push('/access');
      } else {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment is ${transaction.status.toLowerCase()} — '
              'waiting for confirmation.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _checkoutError = 'Status check failed: $e';
      });
    }
  }

  /// Месячный тариф — база для расчёта экономии на длинных планах.
  static SubscriptionPlan? _monthlyPlan(List<SubscriptionPlan> plans) {
    for (final p in plans) {
      if (p.durationDays > 0 && p.durationDays <= 31) return p;
    }
    return null;
  }

  SubscriptionPlan? _selectedPlan() {
    final plans = ref.read(plansProvider).value ?? const <SubscriptionPlan>[];
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => plans.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plansAsync = ref.watch(plansProvider);
    final paymentsEnabled = ref.watch(paymentsEnabledProvider);
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
      title: l10n.premiumTitle,
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
            EmptyState(
              icon: Icons.workspace_premium_rounded,
              title: l10n.premiumNoPlans,
              message: l10n.premiumNoPlansHint,
            )
          else ...[
            _CurrentSubscriptionCard(
              isPremium: isPremium,
              planName: subscription?.planId,
              expiresAt: subscription?.expiresAt,
              onUpgrade: () => ref.read(plansProvider.notifier).refresh(),
            ),
            if (!isPremium) _TrialCard(
              trial: ref.watch(trialStatusProvider).value,
              onStart: () async {
                final ok = await ref.read(trialStatusProvider.notifier).activate();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Trial started — 3 days of access!'
                        : 'Trial activation failed. Try again.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'CHOOSE YOUR PLAN'),
            for (var i = 0; i < plans.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanCard(
                  plan: plans[i],
                  selected: selected?.id == plans[i].id,
                  monthlyPlan: _monthlyPlan(plans),
                  onTap: () => setState(() => _selectedPlanId = plans[i].id),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: 120 + i * 90),
                      duration: 350.ms,
                    ),
              ),
            if (_checkoutError != null) ...[
              const SizedBox(height: 8),
              GlassContainer(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(14),
                color: AppColors.danger.withValues(alpha: 0.06),
                borderColor: AppColors.danger.withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.premiumPaymentFailed,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _checkoutError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final pending = _pendingCheckout;
                              setState(() => _checkoutError = null);
                              if (pending != null) {
                                _checkPaymentStatus();
                              } else {
                                final plan = _selectedPlan();
                                if (plan != null) _checkout(plan);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.refresh_rounded,
                                      size: 15, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.commonRetry,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/support'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.support_agent_rounded,
                                      size: 15, color: AppColors.textSecondary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Support',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // ── Оплата: ожидание подтверждения от провайдера ────────────
            if (_pendingCheckout != null) ...[
              const SizedBox(height: 8),
              _PendingPaymentCard(
                transactionId: _pendingCheckout!.transactionId,
                checkoutUrl: _pendingCheckout!.checkoutUrl,
                paying: _paying,
                success: _paymentSuccess,
                onCheckStatus: _checkPaymentStatus,
              ),
            ],
            const SizedBox(height: 8),
            if (selected != null &&
                _pendingCheckout == null &&
                paymentsEnabled)
              GlassButton(
                label: l10n.premiumGetFor(selected.priceLabel),
                icon: Icons.workspace_premium_rounded,
                loading: _checkingOut,
                gradient: AppColors.premiumGradient,
                foreground: Colors.black87,
                onTap: () => _checkout(selected),
              )
            else if (selected != null && _pendingCheckout == null)
              // Реального платёжного провайдера ещё нет. Показываем цену
              // честно и не притворяемся, что покупка возможна.
              const _PaymentsComingSoonCard(),
            const SizedBox(height: 10),
            Center(
              child: Text(
                paymentsEnabled
                    ? l10n.premiumSecurePaymentNote
                    : l10n.premiumPaymentsComingSoonNote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
              ),
            ),
          ],
          // ── Ad slot #2 (placement: premium) ─────────────────────────────
          const PremiumBannerSection(),
        ],
      ),
    );
  }
}

// ── Trial card ────────────────────────────────────────────────────────────

class _TrialCard extends StatelessWidget {
  const _TrialCard({required this.trial, required this.onStart});

  final TrialStatus? trial;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = trial?.available ?? false;
    if (!available) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        color: AppColors.success.withValues(alpha: 0.05),
        borderColor: AppColors.success.withValues(alpha: 0.25),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded,
                size: 22, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3-day free trial',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.premiumTrialHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: AppColors.connectedGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Start trial',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mock payment card ─────────────────────────────────────────────────────

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({
    required this.transactionId,
    required this.checkoutUrl,
    required this.paying,
    required this.success,
    required this.onCheckStatus,
  });

  final String transactionId;
  final String? checkoutUrl;
  final bool paying;
  final bool success;
  final VoidCallback onCheckStatus;

  /// Провайдер вернул страницу оплаты. Если её нет, платёж подтвердить
  /// нечем — показываем только проверку статуса, но НЕ имитируем успех.
  bool get _hasCheckoutPage =>
      checkoutUrl != null && checkoutUrl!.startsWith('http');

  Future<void> _openCheckout() async {
    final url = checkoutUrl;
    if (url == null) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      // Fallback: copy the URL so the user can open it manually.
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      color: success
          ? AppColors.success.withValues(alpha: 0.07)
          : AppColors.primary.withValues(alpha: 0.05),
      borderColor: success
          ? AppColors.success.withValues(alpha: 0.35)
          : AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.payment_rounded,
                size: 20,
                color: success ? AppColors.success : AppColors.primaryBright,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? l10n.premiumPaymentSuccess
                      : l10n.premiumPaymentTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            success
                ? 'Your subscription and access key are now active.'
                : (_hasCheckoutPage
                    ? 'Pay on the secure provider page, then check the '
                        'status here.'
                    : 'Waiting for payment confirmation from the provider.'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (!success) ...[
            const SizedBox(height: 12),
            if (_hasCheckoutPage) ...[
              GlassButton(
                label: l10n.premiumOpenPaymentPage,
                icon: Icons.open_in_new_rounded,
                loading: paying,
                gradient: AppColors.premiumGradient,
                foreground: Colors.black87,
                onTap: _openCheckout,
              ),
              const SizedBox(height: 8),
            ],
            GlassButton(
              label: l10n.premiumCheckPaymentStatus,
              icon: Icons.verified_rounded,
              loading: paying,
              gradient: AppColors.primaryGradient,
              foreground: Colors.white,
              onTap: onCheckStatus,
            ),
            const SizedBox(height: 6),
            Text(
              'Tx: $transactionId',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
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
    final l10n = AppLocalizations.of(context);
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
                      isPremium ? l10n.premiumActive : l10n.commonFreePlan,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? _expiryText(AppLocalizations.of(context), planName, expiresAt)
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

  String _expiryText(AppLocalizations l10n, String? plan, DateTime? expiresAt) {
    final planLabel =
        plan == null ? l10n.premiumTitle : '${plan[0]}${plan.substring(1).toLowerCase()}';
    if (expiresAt == null) return '$planLabel · Lifetime';
    return '$planLabel · expires ${Formatters.shortDate(expiresAt)}';
  }
}

// ── Оплата скоро ──────────────────────────────────────────────────────────

/// Заглушка на месте кнопки покупки, пока не подключён платёжный
/// провайдер.
///
/// Показывается вместо кнопки «Купить» и НЕ имитирует оплату: раньше
/// здесь была кнопка «Оплатить (демо)», которая выдавала подписку без
/// денег. Такое в релизе означало бы бесплатный премиум для всех.
///
/// Взамен даём рабочий путь: у кого есть код доступа — активирует его
/// прямо сейчас.
class _PaymentsComingSoonCard extends StatelessWidget {
  const _PaymentsComingSoonCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      color: AppColors.premium.withValues(alpha: 0.05),
      borderColor: AppColors.premium.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 20, color: AppColors.premium),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.premiumPaymentsComingSoonTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.premiumPaymentsComingSoonBody,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: l10n.premiumIHaveCode,
            icon: Icons.vpn_key_rounded,
            gradient: AppColors.primaryGradient,
            foreground: Colors.white,
            onTap: () => context.push('/access'),
          ),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    this.monthlyPlan,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  /// Месячный тариф — база для расчёта экономии. Может отсутствовать,
  /// если backend его не отдал.
  final SubscriptionPlan? monthlyPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBest = plan.code == 'YEARLY';
    final perMonth = plan.monthlyEquivalent;
    final monthly = monthlyPlan;
    final savings = monthly == null ? null : plan.savingsAgainst(monthly);

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
                  if (savings != null)
                    Text(
                      l10n.premiumSavings(
                        formatMoney(savings.toDouble(), plan.currency),
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    )
                  else
                    Text(
                      l10n.premiumDaysOfAccess(plan.durationDays),
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
                if (perMonth != null)
                  Text(
                    l10n.premiumPerMonth(
                      formatMoney(perMonth.toDouble(), plan.currency),
                    ),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 14),
          Text(
            l10n.premiumLoadingPlans,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: l10n.commonOffline,
      message:
          'Cannot reach the server. Plans will appear once the connection '
          'is back.',
      actionLabel: l10n.commonRetry,
      onAction: onRetry,
    );
  }
}
