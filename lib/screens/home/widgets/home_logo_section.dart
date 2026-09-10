import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../theme/app_colors.dart';

/// Центральный логотип MOROK на главном экране.
///
/// Анимированная буква M в дымке с пульсирующим свечением.
/// При подключении — свечение усиливается, дымка оживает.
class HomeLogoSection extends ConsumerStatefulWidget {
  const HomeLogoSection({super.key});

  @override
  ConsumerState<HomeLogoSection> createState() => _HomeLogoSectionState();
}

class _HomeLogoSectionState extends ConsumerState<HomeLogoSection>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _smokeController;
  late AnimationController _rotateController;
  late Animation<double> _pulseScale;
  late Animation<double> _glowIntensity;

  final List<_SmokeParticle> _smokeParticles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    // Пульсация свечения
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowIntensity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Движение дымки
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // Медленное вращение ореола
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    )..repeat();

    _generateSmokeParticles();
  }

  void _generateSmokeParticles() {
    _smokeParticles.clear();
    for (int i = 0; i < 15; i++) {
      _smokeParticles.add(_SmokeParticle(
        angle: _random.nextDouble() * 2 * pi,
        radius: 80 + _random.nextDouble() * 60,
        size: _random.nextDouble() * 20 + 10,
        speed: _random.nextDouble() * 0.5 + 0.2,
        opacity: _random.nextDouble() * 0.3 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _smokeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;
    final isConnecting = status == VpnStatus.connecting || status == VpnStatus.reconnecting;
    final isActive = isConnected || isConnecting;

    final accentColor = isConnected 
        ? const Color(0xFF22D3EE)  // Teal
        : const Color(0xFF6C63FF); // Purple

    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Вращающийся ореол из точек
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateController.value * 2 * pi,
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _OrbitDotsPainter(
                    color: accentColor,
                    dotCount: 8,
                    opacity: isActive ? 0.6 : 0.2,
                  ),
                ),
              );
            },
          ),

          // Частицы дымки
          AnimatedBuilder(
            animation: _smokeController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(260, 260),
                painter: _SmokePainter(
                  particles: _smokeParticles,
                  time: _smokeController.value,
                  color: accentColor,
                  intensity: isActive ? 1.0 : 0.5,
                ),
              );
            },
          ),

          // Центральная буква M
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3 * _glowIntensity.value),
                        accentColor.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(
                          alpha: isActive ? 0.5 : 0.2,
                        ),
                        blurRadius: isActive ? 50 : 25,
                        spreadRadius: isActive ? 10 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -4,
                        shadows: [
                          Shadow(
                            color: accentColor.withValues(alpha: 0.8),
                            blurRadius: 20,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Текст "MOROK VPN" под логотипом
          Positioned(
            bottom: 0,
            child: Column(
              children: [
                const Text(
                  'MOROK',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'VPN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor.withValues(alpha: 0.8),
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),

          // Индикатор подключения при загрузке
          if (isConnecting)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat()).scaleXY(
                begin: 0.5,
                end: 1.5,
                duration: 800.ms,
              ),
            ),

          // Зелёная точка при подключении
          if (isConnected)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmokeParticle {
  final double angle;
  final double radius;
  final double size;
  final double speed;
  final double opacity;

  _SmokeParticle({
    required this.angle,
    required this.radius,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _SmokePainter extends CustomPainter {
  final List<_SmokeParticle> particles;
  final double time;
  final Color color;
  final double intensity;

  _SmokePainter({
    required this.particles,
    required this.time,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var p in particles) {
      final angle = p.angle + time * p.speed * 2 * pi;
      final wobble = sin(time * 3 * pi + p.angle * 5) * 15;
      final r = p.radius + wobble;
      
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;

      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter oldDelegate) => true;
}

class _OrbitDotsPainter extends CustomPainter {
  final Color color;
  final int dotCount;
  final double opacity;

  _OrbitDotsPainter({
    required this.color,
    required this.dotCount,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * pi;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDotsPainter oldDelegate) => true;
}
