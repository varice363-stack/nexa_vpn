import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../theme/app_colors.dart';

/// Центральный логотип MOROK VPN на главном экране.
///
/// Анимированный PNG-логотип с пульсирующим свечением и дымкой.
/// При подключении — свечение teal, при отключении — фиолетовое.
class HomeLogoSection extends ConsumerStatefulWidget {
  const HomeLogoSection({super.key});

  @override
  ConsumerState<HomeLogoSection> createState() => _HomeLogoSectionState();
}

class _HomeLogoSectionState extends ConsumerState<HomeLogoSection>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _smokeController;
  late Animation<double> _pulseScale;
  late Animation<double> _glowIntensity;

  final List<_SmokeParticle> _smokeParticles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowIntensity = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _generateSmokeParticles();
  }

  void _generateSmokeParticles() {
    _smokeParticles.clear();
    for (int i = 0; i < 20; i++) {
      _smokeParticles.add(_SmokeParticle(
        angle: _random.nextDouble() * 2 * pi,
        radius: 90 + _random.nextDouble() * 70,
        size: _random.nextDouble() * 25 + 12,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.35 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _smokeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;
    final isConnecting =
        status == VpnStatus.connecting || status == VpnStatus.reconnecting;
    final isActive = isConnected || isConnecting;

    final accentColor =
        isConnected ? const Color(0xFF22D3EE) : const Color(0xFF6C63FF);

    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Дымка вокруг логотипа
          AnimatedBuilder(
            animation: _smokeController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(300, 300),
                painter: _SmokePainter(
                  particles: _smokeParticles,
                  time: _smokeController.value,
                  color: accentColor,
                  intensity: isActive ? 1.0 : 0.4,
                ),
              );
            },
          ),

          // Пульсирующее свечение позади логотипа
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                          alpha: 0.4 * _glowIntensity.value),
                      blurRadius: 60 * _glowIntensity.value,
                      spreadRadius: 20 * _glowIntensity.value,
                    ),
                  ],
                ),
              );
            },
          ),

          // Сам логотип PNG с анимацией
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(
                            alpha: isActive ? 0.6 : 0.2),
                        blurRadius: isActive ? 40 : 20,
                        spreadRadius: isActive ? 8 : 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/home_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),

          // Индикатор подключения
          if (isConnected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat()).scaleXY(
                    begin: 0.8,
                    end: 1.3,
                    duration: 1000.ms,
                  ),
            ),

          if (isConnecting)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.8),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat()).scaleXY(
                    begin: 0.5,
                    end: 1.5,
                    duration: 800.ms,
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
      final wobble = sin(time * 3 * pi + p.angle * 5) * 20;
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
