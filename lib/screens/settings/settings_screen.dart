import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_settings.dart';
import '../../models/vpn_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/section_header.dart';

/// Settings: protocol, DNS, kill switch, behavior, data.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ??
        const AppSettings();

    return AppPage(
      title: 'Settings',
      subtitle: 'Tunnel and privacy preferences',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'CONNECTION'),
          _SegmentedSetting<AppSettings, VpnProtocol>(
            title: 'Protocol',
            subtitle: 'Tunnel transport protocol',
            values: VpnProtocol.values,
            labelOf: (p) => p.label,
            selected: settings.protocol,
            onChanged: (p) =>
                ref.read(settingsProvider.notifier).setProtocol(p),
          ),
          _SegmentedSetting<AppSettings, DnsPreference>(
            title: 'DNS',
            subtitle: 'DNS resolution mode',
            values: DnsPreference.values,
            labelOf: (d) => d.label,
            selected: settings.dns,
            onChanged: (d) => ref.read(settingsProvider.notifier).setDns(d),
          ),
          const SectionHeader(title: 'PRIVACY & SECURITY'),
          _ToggleRow(
            title: 'Kill switch',
            subtitle: 'Block all traffic if the tunnel drops',
            value: settings.killSwitch,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setKillSwitch(v),
          ),
          _ToggleRow(
            title: 'Notifications',
            subtitle: 'Connection events and app alerts',
            value: settings.notificationsEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
          ),
          const SectionHeader(title: 'BEHAVIOR'),
          _ToggleRow(
            title: 'Auto-connect',
            subtitle: 'Connect to the fastest server on app launch',
            value: settings.autoConnect,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAutoConnect(v),
          ),
          const SectionHeader(title: 'DATA'),
          _ActionRow(
            title: 'Clear diagnostic logs',
            subtitle: 'Erase the in-app event buffer',
            onTap: () {
              ref.read(loggerProvider).clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
          ),
          const SectionHeader(title: 'APP'),
          _ActionRow(
            title: 'About Nexa VPN',
            subtitle: 'Version, privacy policy, changelog',
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

class _SegmentedSetting<TState, TValue> extends StatelessWidget {
  const _SegmentedSetting({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final List<TValue> values;
  final String Function(TValue) labelOf;
  final TValue selected;
  final ValueChanged<TValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                GestureDetector(
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: value == selected
                          ? AppColors.primaryGradient
                          : null,
                      color: value == selected
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: value == selected
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      labelOf(value),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: value == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: value == selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
        ),
      ),
    );
  }
}
