import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_notification.dart';
import '../../providers/notifications_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_container.dart';
import '../../core/utils/formatters.dart';

/// In-app notifications feed.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications =
        ref.watch(notificationProvider).value ?? const <AppNotification>[];

    return AppPage(
      title: 'Notifications',
      subtitle: '${notifications.where((n) => !n.read).length} unread',
      actions: [
        GlassContainer(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(11),
          child: GestureDetector(
            onTap: () => ref.read(notificationProvider.notifier).clear(),
            child: const Icon(
              Icons.delete_sweep_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
      child: notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_rounded,
              title: 'All caught up',
              message: 'Connection events and offers will appear here.',
            )
          : Column(
              children: [
                for (final notification in notifications)
                  _NotificationTile(notification: notification),
              ],
            ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = switch (notification.icon) {
      AppNotificationIcon.connection => (
          Icons.vpn_lock_rounded,
          AppColors.primaryBright,
        ),
      AppNotificationIcon.security => (
          Icons.shield_rounded,
          AppColors.success,
        ),
      AppNotificationIcon.promo => (
          Icons.workspace_premium_rounded,
          AppColors.premium,
        ),
      AppNotificationIcon.system => (
          Icons.settings_rounded,
          AppColors.cyan,
        ),
      AppNotificationIcon.info => (
          Icons.info_rounded,
          AppColors.textSecondary,
        ),
    };

    return GestureDetector(
      onTap: () => ref
          .read(notificationProvider.notifier)
          .markRead(notification.id),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        color: notification.read
            ? null
            : AppColors.primary.withValues(alpha: 0.05),
        borderColor: notification.read
            ? null
            : AppColors.primary.withValues(alpha: 0.2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: notification.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryBright,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.shortDateTime(notification.timestamp),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
