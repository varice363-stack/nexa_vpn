import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nexa VPN',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Your connection is protected',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GlassContainer(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(11),
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications are coming soon')),
              );
            },
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
