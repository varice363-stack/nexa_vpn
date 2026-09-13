import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/vpn_status.dart';
import '../../../../providers/vpn_providers.dart';
import '../../../../theme/app_colors.dart';

/// Премиальный заголовок главного экрана MOROK VPN.
///
/// Показывает правильный статус подключения.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(connectionStateProvider);

    // Правильный статус в зависимости от состояния VPN
    final statusText = switch (status) {
      VpnStatus.connected => 'Ваше соединение защищено',
      VpnStatus.connecting => 'Подключение...',
      VpnStatus.reconnecting => 'Переподключение...',
      VpnStatus.disconnecting => 'Отключение...',
      VpnStatus.disconnected => 'VPN отключён',
      VpnStatus.error => 'Ошибка подключения',
    };

    final statusColor = switch (status) {
      VpnStatus.connected => const Color(0xFF22C55E),
      VpnStatus.connecting || VpnStatus.reconnecting => const Color(0xFF6C63FF),
      VpnStatus.disconnecting => AppColors.warning,
      VpnStatus.disconnected => AppColors.textSecondary,
      VpnStatus.error => AppColors.danger,
    };

    return Row(
      children: [
        // Стилизованный логотип MOROK
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2DD4BF), Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'M',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -2,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
        ),

        const SizedBox(width: 12),

        // Название приложения и статус
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Morok VPN',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Иконка SOCKS5 Shield
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: GestureDetector(
            onTap: () {
              // Переход на экран SOCKS5 Shield
              Navigator.pushNamed(context, '/socks5-shield');
            },
            child: const Icon(
              Icons.shield_rounded,
              size: 20,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}
