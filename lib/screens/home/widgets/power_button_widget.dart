import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../providers/connection_source_providers.dart';
import '../../../theme/app_colors.dart';

/// Круглая кнопка питания с бирюзовым свечением.
class PowerButtonWidget extends ConsumerWidget {
  const PowerButtonWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final source = ref.watch(activeSourceProvider);

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
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1F2E),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Icon(
          status == VpnStatus.connected 
              ? Icons.power_off 
              : Icons.power_settings_new,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }
}
