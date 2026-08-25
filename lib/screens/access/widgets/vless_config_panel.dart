import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/access_key.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// Active-key configuration panel: server, protocol, expiration,
/// Copy VLESS / Show QR / Share.
class VlessConfigPanel extends StatelessWidget {
  const VlessConfigPanel({super.key, required this.key_});

  final AccessKey key_;

  Future<void> _copy(BuildContext context) async {
    final uri = key_.configUri;
    if (uri == null) return;
    await Clipboard.setData(ClipboardData(text: uri));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.vlessCopied)),
    );
  }

  Future<void> _share() async {
    final uri = key_.configUri;
    if (uri == null) return;
    await Share.share(uri, subject: 'Nexa VPN — VLESS config');
  }

  void _showQr(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payload = key_.qrPayload ?? key_.configUri;
    if (payload == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.vlessScanHint,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Works with v2rayNG, Shadowrocket, sing-box and other '
                'VLESS clients.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    l10n.commonClose,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final server = key_.server;
    final hasConfig = key_.hasConfig;

    // ACTIVE key without a usable config (missing/unavailable server) —
    // show a safe "Configuration unavailable" state, never a fake URI.
    if (!hasConfig) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        color: AppColors.warning.withValues(alpha: 0.06),
        borderColor: AppColors.warning.withValues(alpha: 0.3),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.vlessUnavailable,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'The assigned server is not ready yet. Please check back '
                    'shortly.',
                    style: TextStyle(
                      fontSize: 12,
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

    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      color: AppColors.success.withValues(alpha: 0.06),
      borderColor: AppColors.success.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                l10n.vlessActiveConfig,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (server != null) ...[
            _InfoRow(
              label: l10n.commonServer,
              value: '${server.flagEmoji}  ${server.name} — ${server.location}',
            ),
            _InfoRow(label: l10n.commonAddress, value: server.ip),
          ],
          _InfoRow(label: l10n.commonProtocol, value: key_.protocol.toUpperCase()),
          _InfoRow(
            label: l10n.commonExpires,
            value: key_.expiresAt == null
                ? l10n.vlessNeverExpires
                : '${Formatters.shortDate(key_.expiresAt!)}'
                    '${key_.daysLeft != null ? ' (${key_.daysLeft} d left)' : ''}',
          ),
          if (hasConfig) ...[
            const SizedBox(height: 8),
            // Masked preview of the URI (never render full secret on screen
            // by default — the user reveals it via Copy).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'vless://••••••••••••••••••••',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.copy_rounded,
                    label: l10n.vlessCopy,
                    onTap: () => _copy(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.qr_code_rounded,
                    label: l10n.vlessShowQr,
                    onTap: () => _showQr(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_rounded,
                    label: l10n.commonShare,
                    onTap: _share,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryBright),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
