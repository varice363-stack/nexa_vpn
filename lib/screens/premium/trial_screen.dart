import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/premium_plan.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Trial activation screen.
///
/// Shows benefits of trial period and allows user to activate 7-day free trial.
/// Designed to maximize conversion: no payment method required, full access.
class TrialScreen extends ConsumerWidget {
  const TrialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subscription = ref.watch(subscriptionProvider);

    return subscription.when(
      data: (state) {
        // If trial is already active, show trial status
        if (state.isTrialActive && state.isTrialValid) {
          return _TrialActiveScreen(state: state);
        }

        // Otherwise show trial offer
        return AppPage(
          title: l10n.trialTitle,
          subtitle: l10n.trialSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _TrialBenefitsCard(),
              const SizedBox(height: 24),
              _TrialOfferCard(
                onActivate: () => _activateTrial(context, ref),
              ),
              const SizedBox(height: 16),
              _NoPaymentRequiredNote(l10n: l10n),
              const SizedBox(height: 24),
              _ViewAllPlansButton(l10n: l10n),
            ],
          ),
        );
      },
      loading: () => const AppPage(
        title: 'Пробный период',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => AppPage(
        title: 'Пробный период',
        child: Center(child: Text('Ошибка: $error')),
      ),
    );
  }

  void _activateTrial(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(subscriptionProvider.notifier).activateTrial();
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.trialActivated),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.commonError}: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Shows when trial is already active.
class _TrialActiveScreen extends StatelessWidget {
  const _TrialActiveScreen({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final daysLeft = state.trialDaysLeft;
    final hoursLeft = state.trialHoursLeft;

    return AppPage(
      title: l10n.trialActiveTitle,
      subtitle: l10n.trialActiveSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _TrialCountdownCard(daysLeft: daysLeft, hoursLeft: hoursLeft),
          const SizedBox(height: 24),
          _TrialFeaturesCard(l10n: l10n),
          const SizedBox(height: 24),
          _UpgradeToPaidCard(l10n: l10n),
        ],
      ),
    );
  }
}

class _TrialBenefitsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.trialBenefitTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.trialBenefitSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrialOfferCard extends StatelessWidget {
  final VoidCallback onActivate;

  const _TrialOfferCard({required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Price
          Text(
            '0 ₽',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.trialPeriod7Days,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // Features list
          ...[
            l10n.trialFeatureUnlimited,
            l10n.trialFeatureAllServers,
            l10n.trialFeature3Devices,
            l10n.trialFeatureFullProtection,
          ].map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          // Activate button
          GlassButton(
            label: l10n.trialActivateButton,
            gradient: AppColors.primaryGradient,
            foreground: Colors.white,
            onTap: onActivate,
          ),
        ],
      ),
    );
  }
}

class _NoPaymentRequiredNote extends StatelessWidget {
  final AppLocalizations l10n;

  const _NoPaymentRequiredNote({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          l10n.trialNoPayment,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ViewAllPlansButton extends StatelessWidget {
  final AppLocalizations l10n;

  const _ViewAllPlansButton({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          // TODO: Navigate to subscription plans screen
        },
        child: Text(l10n.trialViewAllPlans),
      ),
    );
  }
}

class _TrialCountdownCard extends StatelessWidget {
  final int daysLeft;
  final int hoursLeft;

  const _TrialCountdownCard({
    required this.daysLeft,
    required this.hoursLeft,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = (hoursLeft / (7 * 24)).clamp(0.0, 1.0);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.timer,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          // Countdown
          Text(
            daysLeft > 0
                ? l10n.trialDaysLeft(daysLeft)
                : l10n.trialHoursLeft(hoursLeft),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.trialRemaining,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.3 ? AppColors.primary : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialFeaturesCard extends StatelessWidget {
  final AppLocalizations l10n;

  const _TrialFeaturesCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.trialActiveFeatures,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...[
            (Icons.speed, l10n.trialFeatureUnlimited),
            (Icons.dns, l10n.trialFeatureAllServers),
            (Icons.devices, l10n.trialFeature3Devices),
            (Icons.security, l10n.trialFeatureFullProtection),
          ].map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(item.$1, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _UpgradeToPaidCard extends StatelessWidget {
  final AppLocalizations l10n;

  const _UpgradeToPaidCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.trialUpgradeTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.trialUpgradeSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: l10n.trialUpgradeButton,
            onTap: () {
              // TODO: Navigate to subscription plans screen
            },
          ),
        ],
      ),
    );
  }
}
