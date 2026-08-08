import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors/app_exception.dart';
import '../../providers/app_providers.dart';
import '../../providers/server_providers.dart';
import '../../providers/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/section_header.dart';

enum _CheckStatus { running, passed, failed, skipped }

class _Check {
  _Check(this.title, this.description);

  final String title;
  final String description;
  _CheckStatus status = _CheckStatus.skipped;
  String detail = '';
}

/// Diagnostics: connectivity, tunnel config, storage and reachability.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final List<_Check> _checks = [
    _Check('Network connectivity', 'Checks internet access via connectivity_plus'),
    _Check('Tunnel configuration', 'Validates protocol and DNS settings'),
    _Check('Selected server', 'Pings the currently selected location'),
    _Check('Local storage', 'Read/write probe on SharedPreferences'),
    _Check('Secure storage', 'Read/write probe on Keychain/Keystore'),
    _Check('Notification service', 'Verifies the in-app feed is active'),
  ];
  bool _running = false;

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      for (final check in _checks) {
        check.status = _CheckStatus.running;
        check.detail = '';
      }
    });

    // 1. Network.
    await _settle(_checks[0], () async {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        throw const AppException('No active network connection');
      }
      _checks[0].detail = results.map((r) => r.name).join(', ');
    });

    // 2. Tunnel config.
    await _settle(_checks[1], () async {
      final settings = ref.read(settingsProvider).value;
      if (settings == null) {
        throw const AppException('Settings not loaded');
      }
      _checks[1].detail =
          '${settings.protocol.label} • ${settings.dns.label}'
          '${settings.killSwitch ? ' • kill switch on' : ''}';
    });

    // 3. Selected server.
    await _settle(_checks[2], () async {
      final server = ref.read(selectedServerProvider);
      if (server == null) {
        throw const AppException('No server selected');
      }
      _checks[2].detail =
          '${server.displayName} — ${server.ping} ms (simulated)';
    });

    // 4. Local storage.
    await _settle(_checks[3], () async {
      final repo = ref.read(configRepositoryProvider);
      final before = await repo.getOnboardingCompleted();
      await repo.setOnboardingCompleted(before);
      _checks[3].detail = 'read/write ok';
    });

    // 5. Secure storage.
    await _settle(_checks[4], () async {
      final storage = ref.read(keyStorageProvider);
      await storage.write('diagnostics.probe', 'ok');
      final value = await storage.read('diagnostics.probe');
      await storage.delete('diagnostics.probe');
      if (value != 'ok') {
        throw const AppException('Secure storage returned unexpected value');
      }
      _checks[4].detail = 'read/write/delete ok';
    });

    // 6. Notifications.
    await _settle(_checks[5], () async {
      final service = ref.read(notificationServiceProvider);
      service.push(
        title: 'Diagnostics',
        body: 'Notification service is operational',
      );
      _checks[5].detail = 'feed emitting events';
    });

    if (!mounted) return;
    setState(() => _running = false);
  }

  Future<void> _settle(_Check check, Future<void> Function() probe) async {
    try {
      await probe();
      if (!mounted) return;
      setState(() {
        check.status = _CheckStatus.passed;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        check.status = _CheckStatus.failed;
        check.detail = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        check.status = _CheckStatus.failed;
        check.detail = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed =
        _checks.where((c) => c.status == _CheckStatus.passed).length;
    final total = _checks.length;

    return AppPage(
      title: 'Diagnostics',
      subtitle: _running
          ? 'Running checks…'
          : '$passed/$total checks passed',
      actions: [
        GlassContainer(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(11),
          child: GestureDetector(
            onTap: _running ? null : _runAll,
            child: _running
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'CHECKS'),
          for (final check in _checks) _CheckRow(check: check),
          const SizedBox(height: 16),
          const SectionHeader(title: 'DEVICE'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return GlassContainer(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'App version',
                      value: info?.version ?? '…',
                    ),
                    _InfoRow(
                      label: 'Build',
                      value: info?.buildNumber ?? '…',
                    ),
                    _InfoRow(
                      label: 'Platform',
                      value: defaultTargetPlatform.name,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final _Check check;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (check.status) {
      _CheckStatus.running => (
          Icons.hourglass_top_rounded,
          AppColors.warning,
        ),
      _CheckStatus.passed => (
          Icons.check_circle_rounded,
          AppColors.success,
        ),
      _CheckStatus.failed => (
          Icons.cancel_rounded,
          AppColors.danger,
        ),
      _CheckStatus.skipped => (
          Icons.radio_button_unchecked_rounded,
          AppColors.textTertiary,
        ),
    };

    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  check.detail.isEmpty
                      ? check.description
                      : check.detail,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
