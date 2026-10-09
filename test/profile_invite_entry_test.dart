import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/l10n/app_localizations.dart';
import 'package:morok_vpn/providers/identity_providers.dart';
import 'package:morok_vpn/screens/profile/profile_screen.dart';

/// Вход в реферальную программу не должен зависеть от баннеров.
///
/// Вшитую карточку «Пригласить» убрали вместе с фейковым баннером, и без
/// замены приглашение оказалось бы недоступно, пока никто не создал баннер
/// `share:referral`. Постоянная строка в профиле держит вход открытым.
class _FixedIdentity extends IdentityNotifier {
  @override
  Future<String> build() async => 'MOROK-AAAA-BBBB-CCCC-DDDD';
}

void main() {
  testWidgets('профиль: «Пригласить друга» открывает окно с кодом', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityProvider.overrideWith(_FixedIdentity.new),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final entry = find.text('Пригласить друга');
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MOROK-AAAA-BBBB-CCCC-DDDD'), findsOneWidget);
    expect(find.text('Поделиться'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
