import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

import '../../models/app_settings.dart';
import '../../models/vpn_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/locale_providers.dart';
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
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ??
        const AppSettings();

    return AppPage(
      title: l10n.settingsTitle,
      subtitle: l10n.settingsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.settingsSectionConnection),
          // Always-available way to add a key, even when one is already
          // active (home hides its CTA in that case).
          _ActionRow(
            title: l10n.keyEntryOpen,
            subtitle: l10n.keyEntrySubtitle,
            onTap: () => context.push('/key'),
          ),
          _SegmentedSetting<AppSettings, VpnProtocol>(
            title: l10n.settingsProtocol,
            subtitle: l10n.settingsProtocolHint,
            values: VpnProtocol.values,
            labelOf: (p) => p.label,
            selected: settings.protocol,
            onChanged: (p) =>
                ref.read(settingsProvider.notifier).setProtocol(p),
          ),
          _SegmentedSetting<AppSettings, DnsPreference>(
            title: l10n.settingsDns,
            subtitle: l10n.settingsDnsHint,
            values: DnsPreference.values,
            labelOf: (d) => d.label,
            selected: settings.dns,
            onChanged: (d) => ref.read(settingsProvider.notifier).setDns(d),
          ),
          SectionHeader(title: l10n.settingsSectionPrivacy),
          _ToggleRow(
            title: l10n.settingsKillSwitch,
            subtitle: l10n.settingsKillSwitchHint,
            value: settings.killSwitch,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setKillSwitch(v),
          ),
          _ToggleRow(
            title: l10n.settingsNotifications,
            subtitle: l10n.settingsNotificationsHint,
            value: settings.notificationsEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
          ),
          SectionHeader(title: l10n.settingsSectionBehavior),
          _ToggleRow(
            title: l10n.settingsAutoConnect,
            subtitle: l10n.settingsAutoConnectHint,
            value: settings.autoConnect,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAutoConnect(v),
          ),
          SectionHeader(title: l10n.settingsSectionApp),
          _LanguageRow(
            title: l10n.settingsLanguage,
            subtitle: l10n.settingsLanguageHint,
            current: ref.watch(localeProvider),
            onChanged: (v) => ref.read(localeProvider.notifier).set(v),
          ),
          _ActionRow(
            title: l10n.settingsAbout,
            subtitle: l10n.settingsAboutHint,
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

/// Interface language picker. "System" follows the device language, so a
/// Russian phone shows Russian without the user touching anything.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.title,
    required this.subtitle,
    required this.current,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final AppLocale current;
  final ValueChanged<AppLocale> onChanged;

  String _labelFor(AppLocalizations l10n, AppLocale locale) {
    return switch (locale) {
      AppLocale.system => l10n.settingsLanguageSystem,
      AppLocale.en => l10n.settingsLanguageEnglish,
      AppLocale.ru => l10n.settingsLanguageRussian,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<AppLocale>(
              value: current,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              items: [
                for (final locale in AppLocale.values)
                  DropdownMenuItem(
                    value: locale,
                    child: Text(_labelFor(l10n, locale)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
