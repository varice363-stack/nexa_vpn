import 'package:flutter/material.dart';

import '../../data/datasources/static_content.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';

/// Release history.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Changelog',
      subtitle: '${StaticContent.changelog.length} releases',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final release in StaticContent.changelog)
            GlassContainer(
              borderRadius: BorderRadius.circular(20),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'v${release.version}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        release.date,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final note in release.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: AppColors.primaryBright,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              note,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
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
