import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../providers/connection_source_providers.dart';

/// Круглая кнопка питания с бирюзовым свечением и анимацией.
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
      duration: const Duration(milliseconds: 2000),
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 0.5 + 0.5 * _pulseController.value;
        
        return GestureDetector(
          onTap: () async {
            if (source == null) {
              // Переход на экран ввода ключа
              return;
            }
            
            try {
              await ref.read(connectionStateProvider.notifier).toggle(source);
            } catch (e) {
              // Обработка ошибки
            }
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: status == VpnStatus.connected
                    ? [
                        const Color(0xFF22C55E),
                        const Color(0xFF16A34A),
                      ]
                    : [
                        const Color(0xFF2DD4BF),
                        const Color(0xFF14B8A6),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (status == VpnStatus.connected
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF2DD4BF))
                      .withValues(alpha: 0.4 * pulse),
                  blurRadius: 40 * pulse,
                  spreadRadius: 10 * pulse,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              status == VpnStatus.connected 
                  ? Icons.power_off_rounded
                  : Icons.power_settings_new_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
