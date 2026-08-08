import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/server_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/cards/server_card.dart';

/// "Current server" surface — tapping it opens the servers screen.
class HomeConnectionCard extends ConsumerWidget {
  const HomeConnectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(selectedServerProvider);

    if (server == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Current server',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ServerCard(
          server: server,
          onTap: () => context.go('/servers'),
        ),
      ],
    );
  }
}
