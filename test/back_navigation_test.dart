import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:morok_vpn/widgets/common/app_page.dart';

/// Проверка жалобы владельца: «заходишь на баннер / в пробный период,
/// делаешь свайп назад — приложение закрывается, а должно выходить на
/// главный экран».
///
/// Это не «посмотрел глазами», а воспроизведение механизма: системный жест
/// «назад» доставляется в приложение тем же путём, что и на телефоне
/// (`handlePopRoute`), и проверяется, куда приложение ушло.
/// AppPage содержит бесконечную анимацию фона, поэтому pumpAndSettle на нём
/// не дожидается «тишины». Для таких экранов прокручиваем несколько кадров.
Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  GoRouter buildRouter({String initial = '/'}) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Column(
                  children: [
                    const Text('ГЛАВНЫЙ ЭКРАН'),
                    TextButton(
                      onPressed: () => context.push('/premium'),
                      child: const Text('ОТКРЫТЬ ПРОБНЫЙ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Как в приложении: и «пробный период», и «тарифы» — отдельные
          // маршруты верхнего уровня (открываются push поверх главного).
          GoRoute(
            path: '/premium',
            builder: (context, state) => AppPage(
              title: 'ПРОБНЫЙ ПЕРИОД',
              child: TextButton(
                onPressed: () => context.push('/plans'),
                child: const Text('К ТАРИФАМ'),
              ),
            ),
          ),
          GoRoute(
            path: '/plans',
            builder: (context, state) => const AppPage(
              title: 'ТАРИФЫ',
              child: SizedBox.shrink(),
            ),
          ),
        ],
      );

  testWidgets('жест назад с экрана пробного периода возвращает на главный',
      (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // как в жизни: тап по баннеру открывает пробный период
    await tester.tap(find.text('ОТКРЫТЬ ПРОБНЫЙ'));
    await frames(tester);
    expect(find.text('ПРОБНЫЙ ПЕРИОД'), findsOneWidget);

    // свайп-назад (жест с края экрана) — доставляется как системный «назад»
    await tester.binding.handlePopRoute();
    await frames(tester);

    expect(find.text('ГЛАВНЫЙ ЭКРАН'), findsOneWidget,
        reason: 'после жеста назад должно вернуть на главный экран');
    expect(find.text('ПРОБНЫЙ ПЕРИОД'), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });

  testWidgets('жест назад из тарифов возвращает в пробный период, а не домой',
      (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ОТКРЫТЬ ПРОБНЫЙ'));
    await frames(tester);
    await tester.tap(find.text('К ТАРИФАМ'));
    await frames(tester);
    expect(find.text('ТАРИФЫ'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(find.text('ПРОБНЫЙ ПЕРИОД'), findsOneWidget,
        reason: 'первый назад — на шаг назад, а не сразу на главный');

    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(find.text('ГЛАВНЫЙ ЭКРАН'), findsOneWidget);
  });

  testWidgets(
      'если возвращаться некуда (экран открыт «на месте», как было раньше '
      'через go) — жест назад ведёт на главный, приложение не закрывается',
      (tester) async {
    // Именно этот случай давал «свайпнул — приложение вылетело»: экран был
    // единственным в стеке, и система закрывала Activity.
    final router = buildRouter(initial: '/premium');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await frames(tester);
    expect(find.text('ПРОБНЫЙ ПЕРИОД'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await frames(tester);

    expect(find.text('ГЛАВНЫЙ ЭКРАН'), findsOneWidget,
        reason: 'жест назад должен уводить на главный экран');
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });
}
