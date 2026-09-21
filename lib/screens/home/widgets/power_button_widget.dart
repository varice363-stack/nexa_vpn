import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../providers/connection_source_providers.dart';

/// Главная круглая кнопка подключения с логотипом MOROK.
///
/// В отключенном состоянии: чистый логотип без дыма и свечения.
/// В подключенном состоянии: вокруг логотипа загорается бирюзовое свечение и пульсирует туман.
class PowerButtonWidget extends ConsumerStatefulWidget {
  const PowerButtonWidget({super.key});

  @override
  ConsumerState<PowerButtonWidget> createState() => _PowerButtonWidgetState();
}

class _PowerButtonWidgetState extends ConsumerState<PowerButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStateProvider);
    final source = ref.watch(activeSourceProvider);
    final isConnected = status == VpnStatus.connected;
    final isConnecting = status == VpnStatus.connecting;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = isConnected ? (0.5 + 0.5 * _pulseController.value) : 0.0;

        return GestureDetector(
          onTap: () async {
            if (source == null) return;
            try {
              await ref.read(connectionStateProvider.notifier).toggle(source);
            } catch (_) {}
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Внешний дым/туман (ТОЛЬКО при подключении)
              if (isConnected)
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF22D3EE).withValues(alpha: 0.35 * pulse),
                        const Color(0xFF2DD4BF).withValues(alpha: 0.15 * pulse),
                        const Color(0xFF2DD4BF).withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),

              // 2. Сама круглая кнопка с логотипом
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isConnected
                      ? const LinearGradient(
                          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF020617)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(
                    color: isConnected
                        ? const Color(0xFF22D3EE)
                        : Colors.white.withValues(alpha: 0.15),
                    width: isConnected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (isConnected)
                      BoxShadow(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.6 * pulse),
                        blurRadius: 35 * pulse + 10,
                        spreadRadius: 8 * pulse,
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: isConnecting
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF2DD4BF),
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/morok_logo.png',
                          width: 85,
                          height: 85,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
