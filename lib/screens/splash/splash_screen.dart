import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../widgets/branding/morok_logo.dart';

/// Splash screen с анимированным логотипом MOROK VPN.
///
/// Использует программно созданный MorokLogo — никакой PNG.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Запускаем проверку авторизации
    ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Логотип MOROK с анимацией появления
            SizedBox(
              width: 280,
              height: 280,
              child: const MorokLogo(showText: true),
            )
                .animate()
                .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 800.ms,
                  curve: Curves.elasticOut,
                ),

            const SizedBox(height: 48),

            // Индикатор загрузки
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                ),
              ),
            )
                .animate(delay: 400.ms)
                .fadeIn(duration: 600.ms)
                .then()
                .shimmer(
                  duration: 1500.ms,
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                ),
          ],
        ),
      ),
    );
  }
}
