import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';

/// Splash screen with MOROK VPN logo animation.
///
/// Показывает полный логотип с дымкой и анимацией появления.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mistController;
  late AnimationController _logoController;
  late Animation<double> _mistOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  final List<MistParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    ref.watch(authProvider);

    _initAnimations();
    _generateParticles();
  }

  void _initAnimations() {
    // Анимация тумана
    _mistController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _mistOpacity = Tween<double>(begin: 0.0, end: 0.7).animate(
      CurvedAnimation(parent: _mistController, curve: Curves.easeInOut),
    );

    // Появление логотипа
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Запускаем анимацию логотипа
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _logoController.forward();
    });
  }

  void _generateParticles() {
    _particles.clear();
    for (int i = 0; i < 30; i++) {
      _particles.add(MistParticle(
        x: (_random.nextDouble() - 0.5) * 300,
        y: (_random.nextDouble() - 0.5) * 300,
        size: _random.nextDouble() * 12 + 6,
        speed: _random.nextDouble() * 0.8 + 0.3,
        opacity: _random.nextDouble() * 0.6 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _mistController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF05070F),
              Color(0xFF0A0F1E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Фоновый туман
            AnimatedBuilder(
              animation: _mistController,
              builder: (context, child) {
                return CustomPaint(
                  painter: MistBackgroundPainter(
                    particles: _particles,
                    opacity: _mistOpacity.value,
                    time: _mistController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Центральный контент
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Логотип с анимацией
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Image.asset(
                            'assets/images/splash_logo.png',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Индикатор загрузки
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1000.ms, duration: 600.ms)
                      .then()
                      .shimmer(
                        duration: 1500.ms,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Частица тумана
class MistParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  MistParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

/// Художник для фона с туманом
class MistBackgroundPainter extends CustomPainter {
  final List<MistParticle> particles;
  final double opacity;
  final double time;

  MistBackgroundPainter({
    required this.particles,
    required this.opacity,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Рисуем частицы тумана
    for (var particle in particles) {
      final x = center.dx + particle.x + sin(time * 2 * pi + particle.x) * 15;
      final y = center.dy + particle.y + cos(time * 2 * pi + particle.y) * 15;

      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: particle.opacity * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size);

      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }

    // Центральное свечение
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: [
          AppColors.primary.withValues(alpha: 0.2 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.5));

    canvas.drawCircle(center, size.width * 0.5, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant MistBackgroundPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.opacity != opacity;
  }
}
