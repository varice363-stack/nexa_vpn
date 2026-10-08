import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morok_vpn/models/promo_banner.dart';
import 'package:morok_vpn/screens/home/widgets/invite_friend_sheet.dart';

/// Жалоба владельца: «нажимаю баннер „Приведи друга“ — а что я другу скину?
/// как я его приглашу?» Баннер раньше уводил на экран тарифов и всё.
void main() {
  group('баннер-приглашение', () {
    test('share:referral распознаётся как приглашение друга', () {
      const referral = PromoBanner(
        id: '1',
        title: 'Приведи друга',
        description: '15%',
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

      const plain = PromoBanner(id: '3', title: 'Пробный период', description: '...');
      expect(plain.isReferralShare, isFalse);
      expect(plain.hasExternalTarget, isFalse);
    });

    testWidgets('тап открывает окно с готовым текстом и способами отправки',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showInviteFriendSheet(context),
                child: const Text('ТАП'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ТАП'));
      await tester.pumpAndSettle();

      expect(find.text('Пригласить друга'), findsOneWidget);
      expect(find.text('Поделиться'), findsOneWidget);
      expect(find.text('Отправить в Telegram'), findsOneWidget);
      expect(find.text('Скопировать текст'), findsOneWidget);
      // Готовый текст приглашения уже в поле — его и отправит друг
      expect(
        find.textContaining('Пользуюсь MOROK VPN'),
        findsOneWidget,
      );
    });
  });
}
