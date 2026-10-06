import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

import '../../models/app_settings.dart';
import '../../services/system_vpn_settings.dart';
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
          SectionHeader(title: l10n.settingsSectionPrivacy),
          _ActionRow(
            title: l10n.settingsKillSwitch,
            subtitle: l10n.settingsKillSwitchHint,
            onTap: () => _openSystemVpnPanel(context),
          ),
          _ToggleRow(
            title: l10n.settingsNotifications,
            subtitle: l10n.settingsNotificationsHint,
            value: settings.notificationsEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
          ),
          SectionHeader(title: l10n.settingsSectionBehavior),
          _ActionRow(
            title: l10n.settingsAutoConnect,
            subtitle: l10n.settingsAutoConnectHint,
            onTap: () => _openSystemVpnPanel(context),
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

/// Системная панель «Постоянный VPN»: только там Android отдаёт настоящую
/// блокировку трафика без туннеля и автоподключение. Само приложение включить
/// это не может, поэтому ряд не переключатель, а переход — иначе пользователь
/// думал бы, что защита уже включена.
Future<void> _openSystemVpnPanel(BuildContext context) async {
  final ok = await systemVpnSettings.openSystemPanel();
  if (!context.mounted || ok) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Панель VPN недоступна на этой версии Android'),
      behavior: SnackBarBehavior.floating,
    ),
  );
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

/// Backend URL configuration row
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
