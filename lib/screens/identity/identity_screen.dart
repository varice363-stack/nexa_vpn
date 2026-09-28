import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/admin_providers.dart';
import '../../providers/identity_providers.dart';
import '../../services/identity/device_identity.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Экран «Мой код» — то, что заменило регистрацию.
///
/// Здесь человек видит единственное, что связывает его с оплаченным
/// доступом. Ни почты, ни пароля: код создан на этом устройстве и
/// никуда не отправлялся.
class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(identityProvider);
    final isAdmin = ref.watch(adminUnlockedProvider);

    return AppPage(
      title: l10n.identityTitle,
      subtitle: l10n.identitySubtitle,
      child: identity.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _ErrorCard(message: '$e'),
        data: (code) => _Body(code: code, isAdmin: isAdmin),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.code, required this.isAdmin});

  final String code;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          const _AdminCard(),
          const SizedBox(height: 16),
        ],
        _CodeCard(code: code),
        const SizedBox(height: 16),
        const _WarningCard(),
        const SizedBox(height: 16),
        _RestoreCard(onRestore: () => _askRestore(context, ref)),
      ],
    );
  }

  Future<void> _askRestore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            l10n.identityDialogTitle,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.identityDialogBody,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'MOROK-XXXX-XXXX-XXXX-XXXX',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                // 1. Проверяем вход владельца в админку
                final isOwner = await ref
                    .read(adminUnlockedNotifierProvider.notifier)
                    .tryUnlock(text);

                if (isOwner) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Код владельца подтвержден! Панель управления доступна ниже.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                  return;
                }

                // 2. Проверяем обычный код устройства
                if (!DeviceIdentity.isValid(text)) {
                  setDialogState(() => error = l10n.identityCode16Chars);
                  return;
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(l10n.identityApply),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok =
        await ref.read(identityProvider.notifier).restore(controller.text);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.identityCodeApplied : l10n.identityCodeRejected),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }
}

/// Блок управления владельца — отображается в профиле, когда разблокирован админ-код.
class _AdminCard extends ConsumerWidget {
  const _AdminCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      color: Colors.cyan.withValues(alpha: 0.12),
      borderColor: Colors.cyan.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 14, color: Colors.cyanAccent),
                    SizedBox(width: 6),
                    Text(
                      'РЕЖИМ ВЛАДЕЛЬЦА',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.logout_rounded,
                    size: 18, color: AppColors.textTertiary),
                tooltip: 'Заблокировать админку',
                onPressed: () async {
                  await ref
                      .read(adminUnlockedNotifierProvider.notifier)
                      .lock();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Режим владельца заблокирован')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Панель управления MOROK VPN',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Выпуск ключей, управление серверами, пользователями и баннерами',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: 'Открыть Панель Владельца',
            icon: Icons.admin_panel_settings_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
            ),
            foreground: Colors.white,
            onTap: () => context.go('/admin/dashboard'),
          ),
        ],
      ),
    );
  }
}

/// Сам код, крупно и с кнопкой копирования.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = code.split('-');
    final head = parts.first;
    final groups = parts.skip(1).toList();
    final line1 = groups.take(2).join('-');
    final line2 = groups.skip(2).join('-');

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
              const Icon(Icons.vpn_key_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                l10n.identityYourId,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            '$head-$line1\n$line2',
            style: const TextStyle(
              fontSize: 20,
              height: 1.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: l10n.identityCopy,
            icon: Icons.copy_rounded,
            gradient: AppColors.primaryGradient,
            foreground: Colors.white,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.identityCodeCopied)),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Предупреждение о потере.
class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      color: AppColors.premium.withValues(alpha: 0.05),
      borderColor: AppColors.premium.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: AppColors.premium),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.identitySaveNow,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.identitySaveBody,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Перенос доступа с другого устройства.
class _RestoreCard extends StatelessWidget {
  const _RestoreCard({required this.onRestore});

  final VoidCallback onRestore;

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
            l10n.identityTransferTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.identityTransferBody,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: l10n.identityEnterOther,
            icon: Icons.login_rounded,
            onTap: onRestore,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      color: AppColors.danger.withValues(alpha: 0.06),
      borderColor: AppColors.danger.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.identityErrorTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
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
