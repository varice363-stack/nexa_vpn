import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../background/animated_background.dart';
import 'glass_container.dart';

/// Standard page scaffold: animated background, glass header with back
/// button, and a scrollable body.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 110),
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    GlassContainer(
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.all(11),
                      child: GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actions != null) ...[
                      const SizedBox(width: 8),
                      ...actions!,
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: padding,
                  children: [child],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
