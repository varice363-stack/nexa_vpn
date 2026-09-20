import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vpn_status.dart';
import '../../providers/vpn_providers.dart';
import 'widgets/protected_card.dart';
import 'widgets/power_button_widget.dart';
import 'widgets/stats_row.dart';
import 'widgets/server_card.dart';
import 'widgets/partner_banner.dart';

/// Главный экран MOROK VPN.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _smokeController;

  @override
  void initState() {
    super.initState();
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();
  }

  @override
  void dispose() {
    _smokeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: Stack(
        children: [
          // Дымка на фоне
          AnimatedBuilder(
            animation: _smokeController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _SmokePainter(t: _smokeController.value),
              );
            },
          ),

          // Контент
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // Header
                  _buildHeader(context, ref),
                  
                  const SizedBox(height: 8),
                  
                  // Логотип MOROK (компактный и без растягивания)
                  _buildLogo(),
                  
                  const SizedBox(height: 12),
                  
                  // Карточка "ЗАЩИЩЕНО"
                  const ProtectedCard(),
                  
                  const SizedBox(height: 14),
                  
                  // Кнопка питания
                  const PowerButtonWidget(),
                  
                  const SizedBox(height: 14),
                  
                  // Статистика
                  const StatsRow(),
                  
                  const SizedBox(height: 12),
                  
                  // Карточка сервера (показывается ТОЛЬКО при подключении)
                  if (isConnected) ...[
                    const ServerCard(),
                    const SizedBox(height: 12),
                  ],
                  
                  // Баннер партнёрки
                  const PartnerBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Туман вокруг логотипа
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF22D3EE).withValues(alpha: 0.2),
                const Color(0xFF22D3EE).withValues(alpha: 0.08),
                const Color(0xFF22D3EE).withValues(alpha: 0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        ),
        // Оригинальный логотип MOROK (прозрачный)
        Image.asset(
          'assets/images/morok_logo.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 800.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF05070F),
            Color(0xFF0A0F1E),
          ],
        ),
      ),
      child: Row(
        children: [
          // Оригинальный логотип MOROK в левом верхнем углу
          Image.asset(
            'assets/images/morok_logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          const Text(
            'MOROK VPN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Статус подключения
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: status == VpnStatus.connected 
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: status == VpnStatus.connected 
                    ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == VpnStatus.connected 
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.5),
                    boxShadow: [
                      if (status == VpnStatus.connected)
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status == VpnStatus.connected ? 'ЗАЩИЩЕНО' : 'ОТКЛЮЧЕНО',
                  style: TextStyle(
                    color: status == VpnStatus.connected 
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Дымка на фоне.
class _SmokePainter extends CustomPainter {
  _SmokePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
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
