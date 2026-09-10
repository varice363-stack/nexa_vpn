import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';

/// Splash screen с анимированной буквой M и дымкой.
///
/// Чистый дизайн без PNG — только код, плавные анимации, профессиональный вид.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _smokeController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;

  final List<_SmokeParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    ref.watch(authProvider);

    // Анимация дымки
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Появление логотипа
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Появление текста
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    // Запускаем анимации
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _textController.forward();
    });

    _generateParticles();
  }

  void _generateParticles() {
    _particles.clear();
    for (int i = 0; i < 25; i++) {
      _particles.add(_SmokeParticle(
        x: (_random.nextDouble() - 0.5) * 200,
        y: (_random.nextDouble() - 0.5) * 200,
        size: _random.nextDouble() * 30 + 15,
        speed: _random.nextDouble() * 0.4 + 0.2,
        opacity: _random.nextDouble() * 0.4 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _smokeController.dispose();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: Stack(
        children: [
          // Анимированная дымка
          AnimatedBuilder(
            animation: _smokeController,
            builder: (context, child) {
              return CustomPaint(
                painter: _SmokePainter(
                  particles: _particles,
                  time: _smokeController.value,
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
                // Буква M с анимацией
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2DD4BF).withValues(alpha: 0.6),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'M',
                              style: TextStyle(
                                fontSize: 120,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2DD4BF),
                                letterSpacing: -8,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                                    blurRadius: 30,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Текст MOROK VPN
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          const Text(
                            'MOROK',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'VPN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmokeParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  _SmokeParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _SmokePainter extends CustomPainter {
  final List<_SmokeParticle> particles;
  final double time;

  _SmokePainter({
    required this.particles,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var p in particles) {
      final x = center.dx + p.x + sin(time * 2 * pi + p.x * 0.1) * 20;
      final y = center.dy + p.y + cos(time * 2 * pi + p.y * 0.1) * 20;

      final paint = Paint()
        ..color = const Color(0xFF2DD4BF).withValues(alpha: p.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }

    // Центральное свечение
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.4,
        colors: [
          const Color(0xFF2DD4BF).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.3));

    canvas.drawCircle(center, size.width * 0.3, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant _SmokePainter oldDelegate) => true;
}
