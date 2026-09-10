import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vpn_status.dart';
import '../../../providers/vpn_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/branding/morok_logo.dart';

/// Центральный логотип MOROK VPN на главном экране.
class HomeLogoSection extends ConsumerWidget {
  const HomeLogoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;
    final isConnecting =
        status == VpnStatus.connecting || status == VpnStatus.reconnecting;

    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const MorokLogo(),

          if (isConnected)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),

          if (isConnecting)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
