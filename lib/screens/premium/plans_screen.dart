import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/datasources/static_content.dart';
import '../../models/server_plan.dart';
import '../../providers/app_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Экран тарифов: цены приходят с сервера (`GET /plans`).
///
/// Кнопка «Выбрать тариф» раньше вела на саму себя (`context.go('/premium')`
/// из экрана /premium), поэтому не происходило ничего вообще. Теперь она
/// открывает этот список.
///
/// Покупка идёт через владельца: он принимает оплату и выдаёт код
/// `MOROK-XXXX-XXXX`, который вводится в приложении. Никаких «оплата внутри
/// приложения» здесь не обещается — потому что её нет.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  List<ServerPlan> _plans = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await ref.read(subscriptionRepositoryProvider).getPlans();
      if (!mounted) return;
      setState(() => _plans = plans);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isNetworkError
          ? 'Нет связи с сервером. Проверьте интернет и повторите.'
          : e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPurchase(ServerPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PurchaseSheet(plan: plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Тарифы',
      subtitle: 'Цены и сроки — с сервера, оплата по коду',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Тарифы не загрузились: $_error',
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  GlassButton(
                    label: 'Повторить',
                    icon: Icons.refresh_rounded,
                    onTap: _load,
                  ),
                ],
              ),
            )
          else if (_plans.isEmpty)
            const GlassContainer(
              child: Text(
                'Активных тарифов пока нет.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final plan in _plans) ...[
              _PlanCard(plan: plan, onBuy: () => _openPurchase(plan)),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          const GlassContainer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'После оплаты вы получаете код вида MOROK-XXXX-XXXX-XXXX. '
                    'Введите его на главном экране («Добавить ключ или подписку») — '
                    'доступ включится сразу.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onBuy});

  final ServerPlan plan;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                plan.priceLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                plan.daysLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (plan.perMonthLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.perMonthLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          GlassButton(
            label: 'Купить',
            icon: Icons.shopping_cart_outlined,
            onTap: onBuy,
          ),
        ],
      ),
    );
  }
}

/// Как оплатить: связь с владельцем -> оплата -> код.
class _PurchaseSheet extends StatelessWidget {
  const _PurchaseSheet({required this.plan});

  final ServerPlan plan;

  Future<void> _openTelegram() async {
    final handle = StaticContent.supportTelegram.replaceAll('@', '');
    final uri = Uri.tryParse('https://t.me/$handle');
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${plan.name} · ${plan.priceLabel}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Срок: ${plan.daysLabel}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            const Text(
              'Как получить доступ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. Напишите нам в Telegram (или на почту) и скажите, какой тариф нужен.\n'
              '2. Оплатите удобным способом — мы пришлём реквизиты в ответ.\n'
              '3. Получите код MOROK-XXXX-XXXX-XXXX и введите его в приложении.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Открыть Telegram',
              icon: Icons.send_rounded,
              onTap: _openTelegram,
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: 'Скопировать ${StaticContent.supportTelegram}',
              icon: Icons.copy_rounded,
              onTap: () async {
                await Clipboard.setData(
                  const ClipboardData(text: StaticContent.supportTelegram),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Контакт скопирован')),
                );
              },
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: 'Скопировать ${StaticContent.supportEmail}',
              icon: Icons.email_outlined,
              onTap: () async {
                await Clipboard.setData(
                  const ClipboardData(text: StaticContent.supportEmail),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Адрес скопирован')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
