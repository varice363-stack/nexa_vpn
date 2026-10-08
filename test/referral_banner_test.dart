import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morok_vpn/models/promo_banner.dart';
import 'package:morok_vpn/providers/identity_providers.dart';
import 'package:morok_vpn/screens/home/widgets/invite_friend_sheet.dart';

/// Жалоба владельца: «нажимаю баннер „Приведи друга“ — а что я другу скину?»
/// Баннер раньше уводил на экран тарифов и всё.
///
/// Вторая правка (08.10.2026): обещание «15% с его оплаты» убрано — процентов
/// сервер не считал. Программа теперь одна и проверяемая: друг вводит код и
/// получает неделю доступа. Тесты держат именно это обещание.

class _FixedIdentity extends IdentityNotifier {
  @override
  Future<String> build() async => 'MOROK-AAAA-BBBB-CCCC-DDDD';
}

Widget _harness({required Widget child}) => ProviderScope(
      overrides: [
        identityProvider.overrideWith(_FixedIdentity.new),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('баннер-приглашение', () {
    test('share:referral распознаётся как приглашение друга', () {
      const referral = PromoBanner(
        id: '1',
        title: 'Приведи друга',
        description: 'неделя бесплатно',
        targetUrl: 'share:referral',
      );
      expect(referral.isReferralShare, isTrue);
      expect(referral.hasExternalTarget, isFalse);

      const link = PromoBanner(
        id: '2',
        title: 'Акция',
        description: '...',
        targetUrl: 'https://example.com',
      );
      expect(link.isReferralShare, isFalse);
      expect(link.hasExternalTarget, isTrue);

      const plain =
          PromoBanner(id: '3', title: 'Пробный период', description: '...');
      expect(plain.isReferralShare, isFalse);
      expect(plain.hasExternalTarget, isFalse);
    });

    testWidgets('окно показывает свой код и способы отправки', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showInviteFriendSheet(context),
              child: const Text('ТАП'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ТАП'));
      await tester.pumpAndSettle();

      expect(find.text('Пригласить друга'), findsOneWidget);
      // Код приглашения виден целиком — именно его друг введёт в приложении.
      expect(find.text('MOROK-AAAA-BBBB-CCCC-DDDD'), findsOneWidget);
      expect(find.text('Поделиться'), findsOneWidget);
      expect(find.text('Отправить в Telegram'), findsOneWidget);
      expect(find.text('Скопировать текст'), findsOneWidget);
      // Обещание в тексте сообщения.
      expect(find.textContaining('неделю бесплатно'), findsOneWidget);
      // Процентов с оплаты больше не обещаем.
      expect(find.textContaining('15%'), findsNothing);
    });

    test('текст приглашения содержит код и обещание недели', () {
      final text = buildInviteMessage(
        code: 'MOROK-AAAA-BBBB-CCCC-DDDD',
        telegramUrl: 'https://t.me/morokvpn_support',
      );

      expect(text, contains('MOROK-AAAA-BBBB-CCCC-DDDD'));
      expect(text.toLowerCase(), contains('неделю'));
      expect(text, contains('https://t.me/morokvpn_support'));
    });
  });
}
