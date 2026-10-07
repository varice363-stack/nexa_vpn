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
class AdminBackGuard extends StatelessWidget {
  const AdminBackGuard({required this.child, this.onEscape, super.key});

  final Widget child;

  /// Куда идти, когда под экраном пустo. По умолчанию — главный экран.
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
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
