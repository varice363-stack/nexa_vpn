import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';

/// Splash screen с логотипом MOROK VPN (PNG без фона).
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

          // Дымка на фоне
          _SmokeBackground(),

          // Центральный контент
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Логотип MOROK — прозрачный PNG
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/morok_logo.png',
                    fit: BoxFit.contain,
                  ),
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

/// Дымка на фоне splash экрана.
class _SmokeBackground extends StatefulWidget {
  @override
  State<_SmokeBackground> createState() => _SmokeBackgroundState();
}

class _SmokeBackgroundState extends State<_SmokeBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SmokePainter(t: _controller.value),
        );
      },
    );
  }
}

class _SmokePainter extends CustomPainter {
  _SmokePainter({required this.t});

  final double t;

  static const List<_SmokeBlob> _blobs = [
    _SmokeBlob(x: 0.3, y: 0.4, size: 100, speed: 0.3, alpha: 0.08),
    _SmokeBlob(x: 0.7, y: 0.5, size: 120, speed: 0.4, alpha: 0.06),
    _SmokeBlob(x: 0.5, y: 0.3, size: 90, speed: 0.35, alpha: 0.07),
    _SmokeBlob(x: 0.2, y: 0.7, size: 110, speed: 0.25, alpha: 0.05),
    _SmokeBlob(x: 0.8, y: 0.6, size: 95, speed: 0.45, alpha: 0.06),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in _blobs) {
      final x = blob.x * size.width + (t * 50 * blob.speed).remainder(size.width);
      final y = blob.y * size.height + (t * 30 * blob.speed).remainder(size.height);
      
      final paint = Paint()
        ..color = const Color(0xFF2DD4BF).withValues(alpha: blob.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blob.size);
      
      canvas.drawCircle(Offset(x, y), blob.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter oldDelegate) => true;
}

class _SmokeBlob {
  const _SmokeBlob({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.alpha,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double alpha;
}
