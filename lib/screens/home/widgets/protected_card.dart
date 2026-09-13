import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vpn_status.dart';
import '../../providers/vpn_providers.dart';
import '../../theme/app_colors.dart';

/// Карточка "ЗАЩИЩЕНО" с иконкой щита и дымкой.
class ProtectedCard extends ConsumerWidget {
  const ProtectedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Иконка щита с дымкой
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield,
              size: 50,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Текст "ЗАЩИЩЕНО"
          Text(
            isConnected ? 'ЗАЩИЩЕНО' : 'НЕ ЗАЩИЩЕНО',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isConnected ? Colors.white : Colors.white54,
              letterSpacing: 2,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Подпись
          Text(
            'Трафик зашифрован (SOCKS5)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          
          if (isConnected) ...[
            const SizedBox(height: 8),
            Text(
              'Активно: 02ч 15м 48с',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
