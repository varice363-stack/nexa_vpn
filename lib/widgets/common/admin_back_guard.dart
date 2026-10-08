import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Аппаратная «назад» не должна закрывать приложение.
///
/// Экраны админки открываются поверх остального стека, и если под ними ничего
/// не осталось (например, попали через context.go либо стек почистился при
/// перезапуске), системная кнопка Back на последнем маршруте завершает
/// Activity — выглядит это как «свайпнул назад — приложение вылетело».
///
/// Здесь: если выходить некуда, уводим на главный экран.
///
/// `canPop` жёстко false, а решение принимается в момент жеста. Раньше оно
/// вычислялось при сборке (`Navigator.of(context).canPop()`) и успевало
/// разойтись с настоящим стеком go_router — например, после сохранения
/// баннера, где стоял `Navigator.pop` мимо роутера. Тогда жест «назад»
/// попадал в пустой стек и приложение закрывалось.
class AdminBackGuard extends StatelessWidget {
  const AdminBackGuard({required this.child, this.onEscape, super.key});

  final Widget child;

  /// Куда идти, когда под экраном пусто. По умолчанию — главный экран.
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        final escape = onEscape;
        if (escape != null) {
          escape();
        } else {
          context.go('/');
        }
      },
      child: child,
    );
  }
}
