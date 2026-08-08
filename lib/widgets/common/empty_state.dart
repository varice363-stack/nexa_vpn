import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'glass_container.dart';

/// Reusable empty state (favorites, notifications, logs, search).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
