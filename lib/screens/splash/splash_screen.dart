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

          // Туман прямо вокруг логотипа
          Center(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF22D3EE).withValues(alpha: 0.25),
                    const Color(0xFF22D3EE).withValues(alpha: 0.12),
                    const Color(0xFF22D3EE).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ).animate().fadeIn(duration: 2000.ms),
          ),

          // Второй слой тумана — мягче и шире
          Center(
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                    const Color(0xFF2DD4BF).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ).animate().fadeIn(duration: 2500.ms),
          ),

          // Центральный контент
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Логотип MOROK — прозрачный PNG
                Image.asset(
                  'assets/images/morok_logo.png',
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
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

  @override
  void paint(Canvas canvas, Size size) {
    // Мягкий туман — большие размытые круги
    final blobs = [
      _SmokeBlob(x: 0.3, y: 0.4, size: 200, speed: 0.3, alpha: 0.04),
      _SmokeBlob(x: 0.7, y: 0.5, size: 240, speed: 0.4, alpha: 0.03),
      _SmokeBlob(x: 0.5, y: 0.3, size: 180, speed: 0.35, alpha: 0.035),
      _SmokeBlob(x: 0.2, y: 0.7, size: 220, speed: 0.25, alpha: 0.025),
      _SmokeBlob(x: 0.8, y: 0.6, size: 190, speed: 0.45, alpha: 0.03),
      _SmokeBlob(x: 0.5, y: 0.5, size: 300, speed: 0.2, alpha: 0.02),
    ];
    
    for (final blob in blobs) {
      final dx = t * 40 * blob.speed;
      final dy = t * 25 * blob.speed;
      final x = blob.x * size.width + dx % (size.width * 0.3) - size.width * 0.15;
      final y = blob.y * size.height + dy % (size.height * 0.3) - size.height * 0.15;
      
      final paint = Paint()
        ..color = const Color(0xFF22D3EE).withValues(alpha: blob.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blob.size);
      
      canvas.drawCircle(Offset(x, y), blob.size * 0.5, paint);
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
