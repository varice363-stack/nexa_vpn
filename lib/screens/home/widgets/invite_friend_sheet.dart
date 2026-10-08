import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/datasources/static_content.dart';
import '../../../providers/identity_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_button.dart';

/// Окно «Пригласить друга».
///
/// Программа устроена просто и без процентов: у каждого владельца есть свой
/// код (`MOROK-XXXX-XXXX-XXXX-XXXX` — он же код устройства). Друг вводит этот
/// код в приложении и получает **неделю доступа бесплатно**.
///
/// Пригласивший не получает ничего: раньше здесь было обещание «15% с его
/// оплаты», но сервер такие проценты не считал. Обещание в интерфейсе, которое
/// никто не исполняет, — это ложь в интерфейсе, поэтому обещание убрано.
///
/// Способы отправки:
///  * «Поделиться» — системное окно Android (Telegram, WhatsApp, SMS, почта…);
///  * «Telegram» — сразу выбор получателя;
///  * «Скопировать текст» — для любого другого мессенджера.
///
/// Сообщение содержит код и его можно отредактировать (например, вписать своё
/// имя). Код вынесен в отдельную строку с кнопкой копирования: из мессенджера
/// его удобнее копировать по одному, чем вылавливать из текста.
Future<void> showInviteFriendSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0B1120),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _InviteSheet(),
  );
}

/// Текст приглашения. Вынесен отдельно, чтобы его проверял тест: обещание
/// «неделя бесплатно» обязано совпадать с тем, что реально выдаёт сервер
/// (REFERRAL_DAYS = 7 в billing.service.ts).
String buildInviteMessage({required String code, required String telegramUrl}) {
  return 'Привет! Пользуюсь MOROK VPN — быстрый и стабильный, рекомендую.\n'
      'По моему коду ты получишь неделю бесплатно: $code\n'
      'Скачай приложение здесь: $telegramUrl';
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  static const support = StaticContent.supportTelegram; // @morokvpn_support
  static final telegramUrl =
      'https://t.me/${support.replaceAll('@', '')}';

  final TextEditingController _message = TextEditingController();
  String? _code;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// Подставляет готовый текст, как только известен код владельца. Пока код
  /// грузится, поле пустое — лучше пусто, чем текст без кода: друг, получивший
  /// сообщение без кода, не сможет получить неделю.
  void _applyCode(String code) {
    if (_code == code) return;
    _code = code;
    _message.text = buildInviteMessage(code: code, telegramUrl: telegramUrl);
  }

  String get _fullText => _message.text.trim();

  void _notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _shareBySystem() async {
    // Системное окно «Поделиться»: человек сам выбирает мессенджер.
    // API share_plus 10.x: Share.share (в 11-й версии он стал SharePlus).
    final box = context.findRenderObject() as RenderBox?;
    // ignore: deprecated_member_use
    await Share.share(
      _fullText,
      subject: 'MOROK VPN',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _shareToTelegram() async {
    final uri = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(telegramUrl)}'
      '&text=${Uri.encodeComponent(_fullText)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _notify('$what скопирован${what.startsWith('Код') ? '' : 'о'}');
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityProvider);
    final code = identity.value;
    if (code != null) _applyCode(code);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Пригласить друга',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Отправьте другу сообщение с вашим кодом. Он введёт код в '
              'приложении и получит неделю доступа бесплатно.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Свой код — крупно и с кнопкой копирования.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ваш код приглашения',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          code ?? 'загружается…',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 0.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (code != null)
                    IconButton(
                      tooltip: 'Скопировать код',
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: AppColors.primary),
                      onPressed: () => _copy(code, 'Код'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TextField(
                controller: _message,
                maxLines: 6,
                minLines: 3,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Текст приглашения (можно изменить)',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Поделиться',
              icon: Icons.ios_share_rounded,
              gradient: AppColors.primaryGradient,
              foreground: Colors.white,
              onTap: _shareBySystem,
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: 'Отправить в Telegram',
              icon: Icons.send_rounded,
              onTap: _shareToTelegram,
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: 'Скопировать текст',
              icon: Icons.copy_rounded,
              onTap: () => _copy(_fullText, 'Текст приглашения'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Как друг получит неделю: скачает приложение, откроет «Пробный '
              'период» и нажмёт «У меня есть код от друга».',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
