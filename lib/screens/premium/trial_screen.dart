import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/premium_plan.dart';
import '../../providers/subscription_providers.dart';
import '../../services/api/api_exception.dart';
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

  Future<void> _activateTrial(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Пробный период выдаёт СЕРВЕР: подписку TRIAL и настоящий ACTIVE-ключ
      // на 3 дня с лимитом 2 ГБ, который сразу уходит в ядро. После этого
      // экран сам переключается в состояние «активен», а ключ становится
      // активным источником — остаётся нажать кнопку подключения.
      await ref.read(subscriptionProvider.notifier).activateTrial();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Пробный период активирован: 3 дня, лимит 2 ГБ. '
            'Ключ добавлен — подключитесь на главном экране.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_trialErrorMessage(e, l10n)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Объясняет, что именно случилось, вместо «Ошибка: ApiException».
  String _trialErrorMessage(Object e, AppLocalizations l10n) {
    if (e is ApiException) {
      if (e.isNetworkError) {
        return 'Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.';
      }
      final raw = e.message.toUpperCase();
      if (raw.contains('ALREADY BEEN USED') || raw.contains('TRIAL_ALREADY')) {
        return 'Пробный период на этом устройстве уже использован. '
            'Выберите тариф — доступ включим сразу после оплаты.';
      }
      if (raw.contains('ACTIVE SUBSCRIPTION ALREADY EXISTS')) {
        return 'У вас уже есть действующий доступ — пробный не нужен.';
      }
      if (e.statusCode == 401) {
        return 'Сервер не узнал устройство. Перезапустите приложение и повторите.';
      }
      return 'Не получилось активировать пробный период: ${e.message}';
    }
    return '${l10n.commonError}: $e';
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
          const SizedBox(height: 20),
          // Пробный активирован — ведём туда, где включается туннель.
          GlassButton(
            label: 'Подключиться',
            icon: Icons.power_settings_new_rounded,
            gradient: AppColors.primaryGradient,
            foreground: Colors.white,
            onTap: () => context.go('/'),
          ),
          const SizedBox(height: 20),
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
                      style: const TextStyle(
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
          const Text(
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
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // Features list
          // Честно: у пробного есть срок и лимит трафика, и лимит реально
          // работает (его считает сборщик статистики узла). «Безлимит» на
          // пробном был бы обещанием, которое сервер не выполняет.
          ...const [
            '3 дня полного доступа',
            'Лимит трафика 2 ГБ',
            'Все серверы',
            'VLESS + Reality (обход блокировок)',
            'Без привязки карты',
          ].map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
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
        const Icon(
          Icons.lock_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          l10n.trialNoPayment,
          style: const TextStyle(
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
        // Раньше здесь было context.go('/premium') — переход на этот же
        // экран, то есть кнопка не делала ничего. Тарифы живут на /plans.
        onPressed: () => context.push('/plans'),
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
    // Пробный — 3 суток, а не 7: шкала должна показывать правду.
    final progress = (hoursLeft / (3 * 24)).clamp(0.0, 1.0);

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
            style: const TextStyle(
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
              const Icon(
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
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: l10n.trialUpgradeButton,
            // Ведёт на экран тарифов с ценами с сервера, а не на сам себя.
            onTap: () => context.push('/plans'),
          ),
        ],
      ),
    );
  }
}
