import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/models/connection_stats.dart';
import 'package:morok_vpn/models/vpn_status.dart';
import 'package:morok_vpn/providers/vpn_providers.dart';
import 'package:morok_vpn/screens/home/home_screen.dart';
import 'package:morok_vpn/screens/home/widgets/stats_row.dart';

/// Главный экран: статус в шапке — короткая плашка «Активно · время».
/// Большой блок «ЗАЩИЩЕНО» убран и больше не выводится.
class _Connected extends ConnectionNotifier {
  @override
  VpnStatus build() => VpnStatus.connected;
}

Widget _app({
  required VpnStatus status,
  Duration duration = Duration.zero,
}) =>
    ProviderScope(
      overrides: [
        connectionStateProvider.overrideWith(
          () => status == VpnStatus.connected
              ? _Connected()
              : _Fixed(status),
        ),
        connectionStatsProvider.overrideWith(
          (ref) => Stream.value(ConnectionStats(duration: duration)),
        ),
        livePingProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Column(children: [StatsRow()])),
      ),
    );

class _Fixed extends ConnectionNotifier {
  _Fixed(this._value);
  final VpnStatus _value;

  @override
  VpnStatus build() => _value;
}

/// Значения статистики выведены через RichText, поэтому ищем по его тексту.
Finder _richContaining(String fragment) => find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(fragment),
    );

void main() {
  pillTests();

  testWidgets('статистика подписана в Мбит/с, а не в Мб/с', (tester) async {
    await tester.pumpWidget(_app(status: VpnStatus.connected));
    await tester.pump();

    expect(_richContaining('Мбит/с'), findsNWidgets(2));
    expect(_richContaining('Мб/с'), findsNothing);
  });

  testWidgets('статистика без подключения показывает прочерки', (tester) async {
    await tester.pumpWidget(_app(status: VpnStatus.disconnected));
    await tester.pump();

    expect(_richContaining('—'), findsWidgets);
  });
}

void pillTests() {
  testWidgets('плашка при подключении показывает «Активно · 00:12:34»',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VpnStatusPill(
          status: VpnStatus.connected,
          duration: Duration(minutes: 12, seconds: 34),
        ),
      ),
    ));

    expect(find.text('Активно · 00:12:34'), findsOneWidget);
    expect(find.textContaining('ЗАЩИЩЕНО'), findsNothing);
  });

  testWidgets('плашка часов добавляет часы после часа', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VpnStatusPill(
          status: VpnStatus.connected,
          duration: Duration(hours: 1, minutes: 2, seconds: 3),
        ),
      ),
    ));

    expect(find.text('Активно · 01:02:03'), findsOneWidget);
  });

  testWidgets('плашка без подключения — «Отключено», без времени',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VpnStatusPill(
          status: VpnStatus.disconnected,
          duration: Duration(minutes: 5),
        ),
      ),
    ));

    expect(find.text('Отключено'), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('переходные состояния показывают честную подпись', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VpnStatusPill(status: VpnStatus.connecting, duration: Duration.zero))));
    expect(find.text('Подключение…'), findsOneWidget);
  });
}
