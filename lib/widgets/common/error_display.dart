import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'glass_button.dart';

/// Показывает понятное сообщение об ошибке с кнопкой "Повторить".
///
/// Используется когда API вызов упал и нужно показать пользователю
/// что произошло и дать возможность попробовать снова.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}
