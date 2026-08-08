import 'package:flutter/material.dart';

import '../../data/datasources/static_content.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';

/// Privacy policy (static content).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Privacy Policy',
      subtitle: 'Last updated: August 2026',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (title, body) in StaticContent.privacySections)
            GlassContainer(
              borderRadius: BorderRadius.circular(18),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
