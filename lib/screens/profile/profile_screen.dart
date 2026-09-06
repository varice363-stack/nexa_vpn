import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/admin_providers.dart';
import '../../providers/identity_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_list_tile.dart';
import '../../widgets/common/section_header.dart';

/// Профиль: код устройства, настройки, поддержка, админка.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return AppPage(
      title: l10n.profileTitle,
      subtitle: 'Nexa VPN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Код устройства
          _IdentityCodeCard(
            title: l10n.profileMyCode,
            onTap: () => context.push('/identity'),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: l10n.profileAccount),
          GlassListTile(
            icon: Icons.settings_rounded,
            title: l10n.profileSettings,
            subtitle: l10n.profileSettingsHint,
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'БЕЗОПАСНОСТЬ'),
          GlassListTile(
            icon: Icons.shield_rounded,
            title: 'SOCKS5 Shield',
            subtitle: 'Эксклюзив: ваш SOCKS5 защищён паролем',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'УНИКУМ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ),
            onTap: () => context.push('/socks5-shield'),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: l10n.profileSupport.toUpperCase()),
          GlassListTile(
            icon: Icons.support_agent_rounded,
            title: l10n.profileSupport,
            subtitle: l10n.profileSupportHint,
            onTap: () => context.push('/support'),
          ),
          GlassListTile(
            icon: Icons.help_rounded,
            title: l10n.faqTitle,
            subtitle: 'Часто задаваемые вопросы',
            onTap: () => context.push('/faq'),
          ),
          GlassListTile(
            icon: Icons.privacy_tip_rounded,
            title: l10n.privacyPolicyTitle,
            subtitle: 'Соответствует GDPR и 152-ФЗ',
            onTap: () => context.push('/privacy'),
          ),
          GlassListTile(
            icon: Icons.info_rounded,
            title: l10n.profileAbout,
            subtitle: l10n.profileAboutHint,
            onTap: () => context.push('/about'),
          ),
          // Скрытая админка — видна только после ввода кода владельца.
          // Показывается кнопка "Войти как админ" для всех пользователей.
          if (!ref.watch(adminUnlockedProvider)) ...[
            const SizedBox(height: 30),
            _AdminEntryTile(onTap: () => _showAdminLoginDialog(context, ref)),
          ],
          // Раздел владельца — виден только после успешного ввода кода.
          if (ref.watch(adminUnlockedProvider)) ...[
            const SizedBox(height: 20),
            SectionHeader(title: l10n.adminOwnerSection),
            GlassListTile(
              icon: Icons.dashboard_rounded,
              title: l10n.adminDashboard,
              subtitle: l10n.adminDashboardSubtitle,
              onTap: () => context.push('/admin/dashboard'),
            ),
            GlassListTile(
              icon: Icons.vpn_key_rounded,
              title: l10n.adminKeyIssue,
              subtitle: l10n.adminKeyIssueHint,
              onTap: () => context.push('/admin/keys'),
            ),
            GlassListTile(
              icon: Icons.add_photo_alternate_rounded,
              title: 'Создать баннер',
              subtitle: 'Добавить рекламный баннер для партнёров',
              onTap: () => context.push('/admin/create-banner'),
            ),
            const SizedBox(height: 12),
            // Кнопка выхода из админки
            GestureDetector(
              onTap: () {
                ref.read(adminUnlockControllerProvider).lock();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Режим администратора отключён'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: const Text(
                  'Выйти из режима администратора',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAdminLoginDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final scaffold = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'Вход для администратора',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Введите код владельца, чтобы получить доступ к панели управления.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: AppColors.textPrimary,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'NEXA-XXXX-XXXX-XXXX-XXXX',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: AppColors.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Отмена',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final success = ref.read(adminUnlockControllerProvider).tryUnlock(controller.text);
              Navigator.of(dialogContext).pop();
              if (success) {
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Доступ администратора получен!'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('❌ Неверный код владельца'),
                    backgroundColor: AppColors.danger,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Войти',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка "Войти как админ" — скрытая, незаметная.
class _AdminEntryTile extends StatelessWidget {
  const _AdminEntryTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Text(
          'Технический доступ',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textTertiary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Карточка кода устройства.
class _IdentityCodeCard extends ConsumerWidget {
  const _IdentityCodeCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(identityProvider).value;
    final masked = code == null
        ? '…'
        : '${code.split('-').take(2).join('-')}-••••-••••-••••';

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.vpn_key_rounded,
                  size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    masked,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
