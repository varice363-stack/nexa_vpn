import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../widgets/branding/morok_logo.dart';

/// Splash screen с улучшенным визуалом.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: Stack(
        children: [
          // Фоновый градиент
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF05070F),
                    const Color(0xFF0A0F1E),
                    const Color(0xFF05070F),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // Центральный контент
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Логотип MOROK
                SizedBox(
                  width: 240,
                  height: 240,
                  child: const MorokLogo(showText: true),
                )
                    .animate()
                    .fadeIn(duration: 1000.ms, curve: Curves.easeOut)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0),
                      duration: 1000.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 40),

                // Tagline
                const Text(
                  'Растворись в мороке',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8B9AA8),
                    letterSpacing: 2,
                  ),
                )
                    .animate(delay: 600.ms)
                    .fadeIn(duration: 800.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 48),

                // Индикатор загрузки
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF2DD4BF),
                    ),
                  ),
                )
                    .animate(delay: 800.ms)
                    .fadeIn(duration: 600.ms)
                    .then()
                    .shimmer(
                      duration: 1500.ms,
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                    ),
              ],
            ),
          ),

          // Версия внизу
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 1,
              ),
            ).animate(delay: 1200.ms).fadeIn(duration: 600.ms),
          ),
        ],
      ),
    );
  }
}
