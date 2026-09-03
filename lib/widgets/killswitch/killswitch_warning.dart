import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/vpn_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/killswitch_providers.dart';
import '../../theme/app_colors.dart';
import '../../models/vpn_status.dart';

/// Kill Switch warning overlay.
///
/// Shown when Kill Switch is enabled and VPN drops unexpectedly.
/// Blocks the UI until VPN is restored or user dismisses.
class KillSwitchWarning extends ConsumerWidget {
  const KillSwitchWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnStatus = ref.watch(connectionStateProvider);
    final killSwitchEnabled = ref.watch(
      settingsProvider.select((s) => s.value?.killSwitch ?? false),
    );
    final killSwitchService = ref.watch(killSwitchServiceProvider);
    
    // Show warning only when:
    // 1. Kill Switch is enabled
    // 2. VPN is not connected (disconnected, error, or dropped)
    // 3. Kill Switch detected a drop
    final shouldShow = killSwitchEnabled && 
        vpnStatus != VpnStatus.connected && 
        vpnStatus != VpnStatus.connecting &&
        vpnStatus != VpnStatus.disconnecting &&
        killSwitchService.vpnDropped;

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    return _KillSwitchOverlay(
      onReconnect: () async {
        // Try to reconnect
        final source = ref.read(activeSourceProvider);
        if (source != null) {
          try {
            await ref.read(connectionStateProvider.notifier).connect(source);
            killSwitchService.resetVpnDropped();
          } catch (e) {
            // Reconnection failed, keep showing warning
          }
        }
      },
      onDismiss: () {
        // User chose to dismiss - disable Kill Switch
        killSwitchService.resetVpnDropped();
        ref.read(settingsProvider.notifier).setKillSwitch(false);
        killSwitchService.disable();
      },
    );
  }
}

class _KillSwitchOverlay extends StatelessWidget {
  const _KillSwitchOverlay({
    required this.onReconnect,
    required this.onDismiss,
  });

  final VoidCallback onReconnect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  '⚠️ KILL SWITCH ACTIVATED',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'VPN connection was lost.\n'
                  'All internet traffic is blocked to protect your privacy.\n\n'
                  'Your real IP address is NOT exposed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Reconnect button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onReconnect,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try to Reconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Dismiss button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.textTertiary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Disable Kill Switch'),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Info text
                Text(
                  'Tip: Enable "Always-on VPN" in Android settings\n'
                  'for system-level traffic blocking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
