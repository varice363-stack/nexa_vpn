import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';

/// Компактная карточка статуса защиты "ЗАЩИЩЕНО / НЕ ЗАЩИЩЕНО".
class ProtectedCard extends ConsumerWidget {
  const ProtectedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final stats = ref.watch(connectionStatsProvider).value;
    final isConnected = status == VpnStatus.connected;

    String formatDuration(Duration? duration) {
      if (duration == null) return '00ч 00м 00с';
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '${hours}ч ${minutes}м ${seconds}с';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0F1E),
            const Color(0xFF151A28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected 
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected 
                ? const Color(0xFF2DD4BF).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isConnected ? 'ЗАЩИЩЕНО' : 'НЕ ЗАЩИЩЕНО',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isConnected ? const Color(0xFF2DD4BF) : Colors.white.withValues(alpha: 0.6),
              letterSpacing: 2,
              shadows: [
                if (isConnected)
                  Shadow(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            isConnected 
                ? 'Трафик зашифрован (VLESS Reality)' 
                : 'Нажмите кнопку ниже для защиты',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.3,
            ),
          ),
          
          if (isConnected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
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
                      color: const Color(0xFF2DD4BF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Активно: ${formatDuration(stats?.duration)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2DD4BF),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
