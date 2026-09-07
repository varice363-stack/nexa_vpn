import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';

/// Splash screen with MOROK VPN branding animation.
///
/// Атмосфера: буква M растворяется в бирюзовом тумане,
/// создавая ощущение мистики и скрытности.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mistController;
  late AnimationController _glowController;
  late AnimationController _letterController;
  late Animation<double> _mistOpacity;
  late Animation<double> _glowPulse;
  late Animation<double> _letterScale;
  late Animation<double> _letterOpacity;

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
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _mistOpacity = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _mistController, curve: Curves.easeInOut),
    );

    // Пульсация свечения
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Появление буквы M
    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _letterScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _letterController, curve: Curves.elasticOut),
    );

    _letterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _letterController, curve: Curves.easeIn),
    );

    // Запускаем анимацию буквы с небольшой задержкой
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _letterController.forward();
    });
  }

  void _generateParticles() {
    _particles.clear();
    for (int i = 0; i < 20; i++) {
      _particles.add(MistParticle(
        x: (_random.nextDouble() - 0.5) * 200,
        y: (_random.nextDouble() - 0.5) * 200,
        size: _random.nextDouble() * 8 + 4,
        speed: _random.nextDouble() * 0.5 + 0.2,
        opacity: _random.nextDouble() * 0.5 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _mistController.dispose();
    _glowController.dispose();
    _letterController.dispose();
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
                  // Анимированная буква M с свечением
                  AnimatedBuilder(
                    animation: _letterController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _letterScale.value,
                        child: Opacity(
                          opacity: _letterOpacity.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Внешнее свечение
                              AnimatedBuilder(
                                animation: _glowController,
                                builder: (context, child) {
                                  return Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.4 * _glowPulse.value,
                                          ),
                                          blurRadius: 60 * _glowPulse.value,
                                          spreadRadius: 10 * _glowPulse.value,
                                        ),
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.2 * _glowPulse.value,
                                          ),
                                          blurRadius: 100 * _glowPulse.value,
                                          spreadRadius: 20 * _glowPulse.value,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Буква M
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(
                                      fontSize: 80,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.8),
                                          blurRadius: 20,
                                          offset: const Offset(0, 0),
                                        ),
                                        Shadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 40,
                                          offset: const Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Текст MOROK VPN
                  const Text(
                    'MOROK',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                      shadows: [
                        Shadow(
                          color: Color(0xFF22D3EE),
                          blurRadius: 10,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 800.ms)
                      .slideY(begin: 0.3, end: 0, duration: 800.ms),

                  const SizedBox(height: 8),

                  // Подзаголовок VPN
                  const Text(
                    'VPN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 12,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 900.ms, duration: 800.ms),

                  const SizedBox(height: 80),

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
                      .fadeIn(delay: 1400.ms, duration: 600.ms)
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
      final x = center.dx + particle.x + sin(time * 2 * pi + particle.x) * 10;
      final y = center.dy + particle.y + cos(time * 2 * pi + particle.y) * 10;

      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: particle.opacity * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, particle.size);

      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }

    // Центральное свечение
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          AppColors.primary.withValues(alpha: 0.15 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.4));

    canvas.drawCircle(center, size.width * 0.4, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant MistBackgroundPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.opacity != opacity;
  }
}
