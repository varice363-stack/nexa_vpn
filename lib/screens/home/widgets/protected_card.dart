import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';

/// Карточка "ЗАЩИЩЕНО" с улучшенным визуалом.
class ProtectedCard extends ConsumerWidget {
  const ProtectedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0F1E),
            const Color(0xFF151A28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isConnected 
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected 
                ? const Color(0xFF2DD4BF).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Иконка щита с анимацией свечения
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A0F1E),
              border: Border.all(
                color: isConnected 
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isConnected 
                      ? const Color(0xFF2DD4BF).withValues(alpha: 0.4)
                      : Colors.transparent,
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.shield_rounded,
              size: 48,
              color: isConnected ? const Color(0xFF2DD4BF) : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Текст "ЗАЩИЩЕНО" с градиентом
          Text(
            isConnected ? 'ЗАЩИЩЕНО' : 'НЕ ЗАЩИЩЕНО',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isConnected ? Colors.white : Colors.white.withValues(alpha: 0.5),
              letterSpacing: 3,
              shadows: [
                if (isConnected)
                  Shadow(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.5),
                    blurRadius: 20,
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Подпись
          Text(
            'Трафик зашифрован (SOCKS5)',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          
          if (isConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
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
                    'Активно: 02ч 15м 48с',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF2DD4BF),
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
