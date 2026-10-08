import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/datasources/static_content.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_button.dart';

/// Окно «Пригласить друга» — то, чего не хватало баннеру «Приведи друга».
///
/// Раньше баннер без ссылки просто открывал экран тарифов: было непонятно,
/// что именно отправить другу и как получить обещанный процент. Теперь это
/// готовое сообщение и три способа его отправить:
///
///  * «Поделиться» — системное окно Android (Telegram, WhatsApp, SMS, почта…);
///  * «Telegram» — сразу открывает диалог выбора получателя;
///  * «Скопировать текст» — для любого другого мессенджера.
///
/// Текст редактируемый: можно вписать своё имя, чтобы друг сослался на вас.
Future<void> showInviteFriendSheet(BuildContext context) {
  const support = StaticContent.supportTelegram; // @morokvpn_support
  final telegramUrl = 'https://t.me/${support.replaceAll('@', '')}';
  const defaultMessage =
      'Привет! Пользуюсь MOROK VPN — быстрый и стабильный, рекомендую.\n'
      'Оформить доступ: напиши в Telegram, скажи что пришёл от меня.\n';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0B1120),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InviteSheet(
      telegramUrl: telegramUrl,
      support: support,
      initialMessage: defaultMessage,
    ),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({
    required this.telegramUrl,
    required this.support,
    required this.initialMessage,
  });

  final String telegramUrl;
  final String support;
  final String initialMessage;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late final TextEditingController _message =
      TextEditingController(text: widget.initialMessage);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String get _fullText => '${_message.text.trim()}\n${widget.telegramUrl}';

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
      'https://t.me/share/url?url=${Uri.encodeComponent(widget.telegramUrl)}'
      '&text=${Uri.encodeComponent(_message.text.trim())}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _fullText));
    if (!mounted) return;
    _notify('Текст приглашения скопирован');
  }

  @override
  Widget build(BuildContext context) {
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
              'Отправьте другу это сообщение. Когда он оформит доступ и скажет, '
              'что пришёл от вас, — вы получите 15% с его оплаты.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TextField(
                controller: _message,
                maxLines: 5,
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
            const SizedBox(height: 8),
            Text(
              'Получатель увидит ссылку на ${widget.support}',
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
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
              onTap: _copy,
            ),
          ],
        ),
      ),
    );
  }
}
