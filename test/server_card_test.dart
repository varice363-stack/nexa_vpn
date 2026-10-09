import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/models/connection_source.dart';
import 'package:morok_vpn/providers/connection_source_providers.dart';
import 'package:morok_vpn/providers/vpn_providers.dart';
import 'package:morok_vpn/screens/home/widgets/server_card.dart';

/// Карточка на главном экране показывает то, что реально подключено:
/// название ключа и измеренный пинг. Цифры и название из каталога сюда
/// больше не попадают.
class _KeySource extends ActiveSourceNotifier {
  @override
  ConnectionSource? build() => const ConnectionSource(
        id: 'morok:test',
        label: 'Мой ключ',
        uri: 'vless://user@203.0.113.7:443',
        origin: ConnectionOrigin.morok,
      );
}

Widget _app(int? ping) => ProviderScope(
      overrides: [
        activeSourceProvider.overrideWith(_KeySource.new),
        livePingProvider.overrideWith((ref) => Stream.value(ping)),
      ],
      child: const MaterialApp(home: Scaffold(body: ServerCard())),
    );

void main() {
  testWidgets('карточка показывает подключённый ключ и измеренный пинг',
      (tester) async {
    await tester.pumpWidget(_app(38));
    await tester.pump();

    expect(find.text('Мой ключ'), findsOneWidget);
    expect(find.text('Пинг: 38 мс'), findsOneWidget);
  });

  testWidgets('пока замера нет — прочерк, а не число из каталога',
      (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pump();

    expect(find.text('Пинг: — мс'), findsOneWidget);
    expect(find.textContaining('45'), findsNothing);
  });
}
