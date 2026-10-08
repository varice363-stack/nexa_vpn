import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../background/animated_background.dart';

/// Базовая страница с анимированным фоном и staggered анимацией.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding,
    this.showBackButton = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    // Системная «назад» (свайп с края / кнопка) обязана вести себя как стрелка
    // в шапке: стрелка проверяет canPop и при пустом стеке уводит на главную,
    // а жест такой проверки не имел - на вершине стека он закрывал приложение.
    // PopScope здесь, а не в отдельных экранах: чинит сразу все страницы на AppPage.
    // canPop здесь ВСЕГДА false, а решение принимается в момент жеста.
    // Раньше стояло canPop: Navigator.of(context).canPop() — величина,
    // посчитанная при сборке: пока экран жил, стек успевал измениться
    // (например, после сохранения баннера, где стоял Navigator.pop вместо
    // go_router pop), и жест «назад» уходил не туда — вплоть до закрытия
    // приложения. Теперь: есть куда возвращаться — возвращаемся, нет —
    // уходим на главный экран.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else if (showBackButton) {
          context.go('/');
        }
      },
      child: Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    if (showBackButton)
                      GestureDetector(
                        // Тот же порядок, что и у системного жеста: pop через
                        // go_router, иначе его стек расходится с навигатором и
                        // следующий жест «назад» промахивается.
                        onTap: () {
                          final router = GoRouter.of(context);
                          if (router.canPop()) {
                            router.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.glassFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.glassBorder,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    if (showBackButton) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Контент
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
