import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Primary glass gradient button used across screens.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.gradient = AppColors.primaryGradient,
    this.foreground = Colors.white,
    this.expand = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool loading;
  final Gradient gradient;
  final Color foreground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: loading ? 0.1 : 0.3),
              blurRadius: 22,
            ),
          ],
        ),
        child: expand ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}
