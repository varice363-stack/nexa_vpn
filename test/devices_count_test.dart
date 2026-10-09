import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/l10n/app_localizations.dart';
import 'package:morok_vpn/screens/settings/devices_screen.dart';

/// Экран «Устройства» не должен показывать выдуманный лимит.
///
/// Раньше шапка показывала «X / Y» и название тарифа из старой модели:
/// `devicesUsed` никто не заполнял (всегда 0), а лимит брался из таблицы
/// тарифов, которую приложение не применяет. Теперь — только число
/// устройств из ответа GET /devices.
DeviceRow _device(String id) => DeviceRow(
      id: id,
      name: 'Телефон $id',
      os: 'android',
      lastConnectedAt: DateTime(2026, 10, 1),
      keysBound: 0,
    );

Future<void> _pump(WidgetTester tester, List<DeviceRow> rows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        devicesListProvider.overrideWith((ref) async => rows),
      ],
      child: const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('показывает число устройств из списка', (tester) async {
    await _pump(tester, [_device('a'), _device('b')]);

    expect(find.text('Подключено устройств: 2'), findsOneWidget);
  });

  testWidgets('без устройств — честный ноль, без лимита и тарифа', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Подключено устройств: 0'), findsOneWidget);
    expect(find.textContaining(' / '), findsNothing);
    expect(find.textContaining('FREE'), findsNothing);
    expect(find.textContaining('STANDARD'), findsNothing);
    expect(find.textContaining('PREMIUM'), findsNothing);
    expect(find.textContaining('Достигнут лимит'), findsNothing);
  });
}
