/// Экран «Устройства»: реальные данные с бэкенда.
///
/// Предыдущая версия была декорацией: `_getMockDevices()` рисовал Pixel 6 /
/// iPhone 13 / MacBook Pro по количеству `state.devicesUsed`, кнопка
/// «Отключить» показывала снэкбар «устройство отключено» и не звала никуда,
/// а в коде висело `// TODO: Call backend API to disconnect device`.
/// Итог для пользователя: он «отвязывал» телефон, телефон продолжал ходить по
/// ключу, а на новой трубке ключ не активировался (boundDevice занят), и
/// никаких подсказок об этом не было.
///
/// Теперь: GET /devices и DELETE /devices/:id (бэкенд помечает устройство
/// отозванным и отвязывает его ключи — код можно ввести на новом телефоне).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/premium_plan.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Запись /devices в том виде, как её отдаёт бэкенд
/// (backend/src/devices/devices.service.ts → list()).
class DeviceRow {
  const DeviceRow({
    required this.id,
    required this.name,
    required this.os,
    required this.lastConnectedAt,
    required this.keysBound,
  });

  final String id;
  final String name;
  final String os;
  final DateTime lastConnectedAt;

  /// Сколько ключей доступа привязано к этому устройству.
  final int keysBound;

  factory DeviceRow.fromJson(Map<String, dynamic> json) {
    return DeviceRow(
      id: json['deviceId'] as String,
      name: (json['deviceName'] as String?) ?? '—',
      os: (json['os'] as String?) ?? '—',
      lastConnectedAt: json['lastConnectedAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['lastConnectedAt'] as String),
      keysBound: (json['keysBound'] as num?)?.toInt() ?? 0,
    );
  }
}

final devicesListProvider = FutureProvider<List<DeviceRow>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/devices');
  if (data is! List) return const <DeviceRow>[];
  return data
      .whereType<Map<String, dynamic>>()
      .map(DeviceRow.fromJson)
      .toList(growable: false);
});

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subscription = ref.watch(subscriptionProvider);
    final devices = ref.watch(devicesListProvider);

    return AppPage(
      title: l10n.devicesTitle,
      subtitle: l10n.devicesSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeviceLimitCard(
            devicesUsed: subscription.value?.devicesUsed ?? 0,
            deviceLimit: subscription.value?.deviceLimit ?? 1,
            tier: subscription.value?.tier ?? SubscriptionTier.free,
          ),
          const SizedBox(height: 16),
          devices.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorBox(
              message: '${l10n.devicesLoadFailed}\n$e',
              onRetry: () => ref.invalidate(devicesListProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return GlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    l10n.devicesEmpty,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    _DeviceCard(
                      row: row,
                      onUnbind: () => _confirmAndUnbind(context, ref, row),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (subscription.value != null && !subscription.value!.canAddDevice)
            const _UpgradePrompt(),
        ],
      ),
    );
  }

  Future<void> _confirmAndUnbind(
    BuildContext context,
    WidgetRef ref,
    DeviceRow row,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.devicesUnbindTitle),
        content: Text(l10n.devicesUnbindBody(row.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.devicesUnbindConfirm,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).delete('/devices/${row.id}');
      ref.invalidate(devicesListProvider);
      // Лимит устройств живёт в подписке — её тоже надо переснять, иначе
      // счётчик «N / M» на этом же экране останется вчерашним.
      ref.invalidate(subscriptionProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.devicesDisconnected(row.name)),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.devicesUnbindFailed('$e'))),
      );
    }
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.row, required this.onUnbind});

  final DeviceRow row;
  final Future<void> Function() onUnbind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smartphone_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${row.os} · ${_relative(context, l10n, row.lastConnectedAt)}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            row.keysBound == 0
                ? l10n.devicesNoKeys
                : l10n.devicesKeysBound(row.keysBound),
            style: TextStyle(
              fontSize: 12,
              color: row.keysBound == 0
                  ? AppColors.textSecondary
                  : AppColors.warning,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUnbind,
              child: Text(
                l10n.devicesUnbind,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relative(BuildContext context, AppLocalizations l10n, DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return l10n.devicesJustNow;
    if (diff.inMinutes < 60) return l10n.devicesMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.devicesHoursAgo(diff.inHours);
    return l10n.devicesDaysAgo(diff.inDays);
  }
}

class _DeviceLimitCard extends StatelessWidget {
  const _DeviceLimitCard({
    required this.devicesUsed,
    required this.deviceLimit,
    required this.tier,
  });

  final int devicesUsed;
  final int deviceLimit;
  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = deviceLimit <= 0 ? 0.0 : devicesUsed / deviceLimit;

    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      color: AppColors.primary.withValues(alpha: 0.06),
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.devices_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.devicesLimit,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$devicesUsed / $deviceLimit',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                tier.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surface.withValues(alpha: 0.1),
              valueColor: progress > 0.8
                  ? const AlwaysStoppedAnimation<Color>(AppColors.warning)
                  : const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            devicesUsed == 0
                ? l10n.devicesNoConnections
                : devicesUsed >= deviceLimit
                    ? l10n.devicesLimitReached
                    : l10n.devicesSlotsAvailable(deviceLimit - devicesUsed),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradePrompt extends StatelessWidget {
  const _UpgradePrompt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 18,
                color: AppColors.premium,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.devicesUpgradeTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.devicesUpgradeBody,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: l10n.devicesUpgradeButton,
            icon: Icons.arrow_forward_rounded,
            gradient: AppColors.premiumGradient,
            foreground: Colors.white,
            onTap: () => context.go('/premium'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.danger,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ),
        ],
      ),
    );
  }
}
