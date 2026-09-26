import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vpn_status.dart';
import '../../providers/connection_source_providers.dart';
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
    final activeSource = ref.watch(activeSourceProvider);
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
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                children: [
                  // Хедер
                  _buildHeader(context, ref),
                  
                  const SizedBox(height: 12),

                  // Кнопка добавления ключа / подписки (как в Hiddify)
                  _buildAddKeyButton(context, activeSource?.label),
                  
                  const SizedBox(height: 14),
                  
                  // Компактная карточка "ЗАЩИЩЕНО / НЕ ЗАЩИЩЕНО"
                  const ProtectedCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Круглая кнопка с встроенным логотипом MOROK
                  // (Чистая без дыма когда выключено, с дымом/свечением при подключении)
                  const PowerButtonWidget(),
                  
                  const SizedBox(height: 20),
                  
                  // Статистика (Пинг / Загрузка / Отдача)
                  const StatsRow(),
                  
                  const SizedBox(height: 14),
                  
                  // Карточка активного сервера (показывается ТОЛЬКО при подключении)
                  if (isConnected) ...[
                    const ServerCard(),
                    const SizedBox(height: 14),
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

  /// Яркая видимая кнопка вставки ключа / подписки (по аналогии с Hiddify)
  Widget _buildAddKeyButton(BuildContext context, String? activeLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push('/key'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF10172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF2DD4BF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeLabel != null ? 'Ключ активен: $activeLabel' : 'Добавить ключ или подписку',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Вставьте код MOROK, vless:// или ссылку подписки',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF2DD4BF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Image.asset(
            'assets/images/morok_logo.png',
            width: 30,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: status == VpnStatus.connected 
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 10.5,
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
