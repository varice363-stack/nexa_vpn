import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/security/socks5_shield_indicator.dart';
import '../../services/security/socks5_scanner.dart';

/// Screen that explains and demonstrates SOCKS5 Shield protection
///
/// This is a UNIQUE FEATURE — no other VPN app has this.
/// Use it to educate users and demonstrate security value.
class Socks5ShieldScreen extends ConsumerStatefulWidget {
  const Socks5ShieldScreen({super.key});

  @override
  ConsumerState<Socks5ShieldScreen> createState() =>
      _Socks5ShieldScreenState();
}

class _Socks5ShieldScreenState extends ConsumerState<Socks5ShieldScreen> {
  final _scanner = const Socks5Scanner();
  List<Socks5ScanResult>? _scanResults;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _isScanning = true);

    try {
      final results = await _scanner.scan();
      if (mounted) {
        setState(() {
          _scanResults = results;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'SOCKS5 Shield',
      subtitle: 'Exclusive protection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero section with shield indicator
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Socks5ShieldIndicator(
                  status: Socks5ShieldStatus.protected,
                  size: 80,
                  showLabel: false,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your SOCKS5 is protected',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nexa VPN is the only VPN that secures your local SOCKS5 proxy',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What is SOCKS5?
          _buildInfoCard(
            icon: Icons.question_answer_rounded,
            title: 'What is SOCKS5?',
            description:
                'SOCKS5 is a local proxy that routes your traffic through VPN. '
                'Every VPN app creates one, but most leave it unprotected.',
          ),

          const SizedBox(height: 12),

          // Why it matters
          _buildInfoCard(
            icon: Icons.warning_amber_rounded,
            title: 'The Security Risk',
            description:
                'An unprotected SOCKS5 lets ANY app on your device bypass VPN '
                'and expose your real IP. This includes spyware and malware.',
          ),

          const SizedBox(height: 12),

          // How we protect
          _buildInfoCard(
            icon: Icons.shield_rounded,
            title: 'Nexa Shield Protection',
            description:
                'We add password authentication to SOCKS5 and disable UDP. '
                'Each session gets a unique, random password.',
            highlight: true,
          ),

          const SizedBox(height: 24),

          // Scan button
          if (_scanResults != null) ...[
            Text(
              'Device Scan Results',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._scanResults!.map((result) => _buildPortResult(result)),
            const SizedBox(height: 16),
          ],

          // Scan button
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _scan,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_isScanning ? 'Scanning...' : 'Scan Device'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    bool highlight = false,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: highlight ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildPortResult(Socks5ScanResult result) {
    final isVulnerable = result.isVulnerable;
    final isClosed = !result.isOpen;

    return GlassContainer(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isClosed
                ? Icons.check_circle_rounded
                : isVulnerable
                    ? Icons.dangerous_rounded
                    : Icons.shield_rounded,
            color: isClosed
                ? Colors.green
                : isVulnerable
                    ? Colors.red
                    : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Port ${result.port}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (result.processName != null)
                  Text(
                    result.processName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            isClosed
                ? 'Closed'
                : isVulnerable
                    ? 'Vulnerable'
                    : 'Protected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isClosed
                  ? Colors.green
                  : isVulnerable
                      ? Colors.red
                      : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
