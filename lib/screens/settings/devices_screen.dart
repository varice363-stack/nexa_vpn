import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/device_info.dart';
import '../../models/premium_plan.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Screen for managing connected devices.
///
/// Shows list of devices connected to user's account with ability to
/// disconnect devices remotely. Displays device limit based on subscription tier.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subscription = ref.watch(subscriptionProvider);

    return subscription.when(
      loading: () => const AppPage(
        title: 'Devices',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppPage(
        title: 'Devices',
        child: Center(child: Text('Error: $e')),
      ),
      data: (state) => _DevicesContent(state: state),
    );
  }
}

class _DevicesContent extends StatelessWidget {
  const _DevicesContent({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Mock devices for demonstration
    // In real app, this would come from backend API
    final devices = _getMockDevices(state.devicesUsed);

    return AppPage(
      title: l10n.devicesTitle,
      subtitle: l10n.devicesSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeviceLimitCard(
            devicesUsed: state.devicesUsed,
            deviceLimit: state.deviceLimit,
            tier: state.tier,
          ),
          const SizedBox(height: 16),
          if (state.devicesUsed == 0)
            _EmptyDevicesMessage()
          else
            ...devices.map((device) => _DeviceCard(device: device)),
          const SizedBox(height: 16),
          if (!state.canAddDevice) _UpgradePrompt(),
        ],
      ),
    );
  }

  List<DeviceInfo> _getMockDevices(int count) {
    // Mock data — in real app, fetch from backend
    if (count == 0) return [];
    return [
      DeviceInfo(
        deviceId: 'device-1',
        deviceName: 'Pixel 6',
        os: 'Android 13',
        lastConnectedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isConnected: true,
        lastIpAddress: '185.22.33.44',
      ),
      if (count > 1)
        DeviceInfo(
          deviceId: 'device-2',
          deviceName: 'iPhone 13',
          os: 'iOS 16',
          lastConnectedAt: DateTime.now().subtract(const Duration(days: 1)),
          isConnected: false,
          lastIpAddress: '185.22.33.45',
        ),
      if (count > 2)
        DeviceInfo(
          deviceId: 'device-3',
          deviceName: 'MacBook Pro',
          os: 'macOS 13',
          lastConnectedAt: DateTime.now().subtract(const Duration(days: 3)),
          isConnected: false,
          lastIpAddress: '185.22.33.46',
        ),
    ];
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
    final progress = devicesUsed / deviceLimit;

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
              value: progress,
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
                : devicesUsed == deviceLimit
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final DeviceInfo device;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeAgo = _formatTimeAgo(device.lastConnectedAt, l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        color: AppColors.surface.withValues(alpha: 0.05),
        borderColor: AppColors.border.withValues(alpha: 0.2),
        child: Row(
          children: [
            Icon(
              _getDeviceIcon(device.os),
              size: 32,
              color: device.isConnected
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.os} • $timeAgo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (device.isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                color: AppColors.danger,
                onPressed: () => _showDisconnectDialog(context, device),
                tooltip: l10n.devicesDisconnect,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String os) {
    if (os.contains('Android')) return Icons.phone_android_rounded;
    if (os.contains('iOS')) return Icons.phone_iphone_rounded;
    if (os.contains('macOS')) return Icons.laptop_mac_rounded;
    if (os.contains('Windows')) return Icons.laptop_windows_rounded;
    return Icons.devices_rounded;
  }

  String _formatTimeAgo(DateTime time, AppLocalizations l10n) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.devicesJustNow;
    if (diff.inMinutes < 60) return l10n.devicesMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.devicesHoursAgo(diff.inHours);
    return l10n.devicesDaysAgo(diff.inDays);
  }

  void _showDisconnectDialog(BuildContext context, DeviceInfo device) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.devicesDisconnectTitle),
        content: Text(l10n.devicesDisconnectBody(device.deviceName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call backend API to disconnect device
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.devicesDisconnected(device.deviceName)),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text(
              l10n.commonConfirm,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevicesMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(24),
      color: AppColors.surface.withValues(alpha: 0.05),
      borderColor: AppColors.border.withValues(alpha: 0.2),
      child: Column(
        children: [
          const Icon(
            Icons.devices_other_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.devicesEmpty,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UpgradePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      color: AppColors.premium.withValues(alpha: 0.08),
      borderColor: AppColors.premium.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.upgrade_rounded,
                size: 20,
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
            onTap: () {
              // TODO: Navigate to subscription screen
            },
          ),
        ],
      ),
    );
  }
}
