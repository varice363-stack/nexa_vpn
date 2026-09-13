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

/// Главный экран MOROK VPN с дымкой на фоне.
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
              child: Column(
                children: [
                  // Header
                  _buildHeader(context, ref),
                  
                  const SizedBox(height: 20),
                  
                  // Логотип MOROK
                  _buildLogo(),
                  
                  const SizedBox(height: 20),
                  
                  // Карточка "ЗАЩИЩЕНО"
                  const ProtectedCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Кнопка питания
                  const PowerButtonWidget(),
                  
                  const SizedBox(height: 20),
                  
                  // Статистика
                  const StatsRow(),
                  
                  const SizedBox(height: 16),
                  
                  // Карточка сервера (только при подключении)
                  if (isConnected) ...[
                    const ServerCard(),
                    const SizedBox(height: 16),
                  ],
                  
                  // Баннер партнёрки
                  const PartnerBanner(),
                  
                  const SizedBox(height: 100), // Отступ для нижней навигации
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.25),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF05070F),
            const Color(0xFF0A0F1E),
          ],
        ),
      ),
      child: Row(
        children: [
          // Логотип M
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                const SizedBox(width: 8),
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

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF2DD4BF),
        unselectedItemColor: Colors.white.withValues(alpha: 0.4),
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          // Навигация
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.public_rounded),
            label: 'Серверы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Профиль',
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

  static const List<_SmokeBlob> _blobs = [
    _SmokeBlob(x: 0.3, y: 0.4, size: 120, speed: 0.3, alpha: 0.06),
    _SmokeBlob(x: 0.7, y: 0.5, size: 140, speed: 0.4, alpha: 0.05),
    _SmokeBlob(x: 0.5, y: 0.3, size: 110, speed: 0.35, alpha: 0.06),
    _SmokeBlob(x: 0.2, y: 0.7, size: 130, speed: 0.25, alpha: 0.04),
    _SmokeBlob(x: 0.8, y: 0.6, size: 115, speed: 0.45, alpha: 0.05),
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
