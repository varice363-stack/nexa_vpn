import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/access_key.dart';
import '../../providers/app_providers.dart';
import '../../providers/admin_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Admin: mint sellable access codes and review every key in the system.
///
/// Issuing used to require a PowerShell call against the API, which meant the
/// owner could not sell a key without a computer and a running backend shell.
/// The endpoints are ADMIN-guarded server-side; this screen is the client for
/// them, and it is hidden entirely from non-admin accounts.
class AdminKeysScreen extends ConsumerStatefulWidget {
  const AdminKeysScreen({super.key});

  @override
  ConsumerState<AdminKeysScreen> createState() => _AdminKeysScreenState();
}

class _AdminKeysScreenState extends ConsumerState<AdminKeysScreen> {
  final _nameController = TextEditingController();

  /// Common selling durations; 0 is a lifetime key.
  static const _durations = <int>[30, 90, 365, 0];

  int _duration = 30;
  bool _issuing = false;
  String? _error;
  AccessKey? _justIssued;

  late Future<List<AccessKey>> _keysFuture;

  @override
  void initState() {
    super.initState();
    _keysFuture = _loadKeys();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<List<AccessKey>> _loadKeys() =>
      ref.read(accessRepositoryProvider).getAllKeys();

  Future<void> _refresh() async {
    setState(() => _keysFuture = _loadKeys());
    await _keysFuture;
  }

  Future<void> _issue() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _issuing = true;
      _error = null;
    });

    try {
      final key = await ref.read(accessRepositoryProvider).issueCode(
            name: _nameController.text,
            durationDays: _duration,
          );
      if (!mounted) return;
      setState(() {
        _justIssued = key;
        _nameController.clear();
      });
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          // 403 here means the account is not an admin — say so plainly
          // instead of showing a raw status code.
          _error = e.statusCode == 403
              ? l10n.adminNoAccess
              : e.message;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = l10n.adminIssueFailed('$e'));
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  String _durationLabel(int days, AppLocalizations l10n) => switch (days) {
        0 => l10n.adminDurationForever,
        30 => l10n.adminDuration30Days,
        90 => l10n.adminDuration90Days,
        365 => l10n.adminDuration1Year,
        _ => l10n.adminDurationDays(days),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Экран умеет выпускать коды на продажу, поэтому проверка стоит здесь,
    // а не только в меню: попасть сюда по прямой ссылке нельзя.
    // Признак владельца — совпадение кода устройства с OWNER_CODE сборки.
    if (!ref.watch(adminUnlockedProvider)) {
      return AppPage(
        title: l10n.adminOwnerSection,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            l10n.adminOwnerOnly,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return AppPage(
      title: l10n.adminTitle,
      subtitle: l10n.adminSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _issueCard(context, l10n),
          if (_justIssued != null) ...[
            const SizedBox(height: 12),
            _issuedCard(_justIssued!, context, l10n),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                l10n.adminAllKeys,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.textSecondary,
                tooltip: l10n.adminRefresh,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _keysList(context, l10n),
        ],
      ),
    );
  }

  Widget _issueCard(BuildContext context, AppLocalizations l10n) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_issuing,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: l10n.adminNameLabel,
              hintText: l10n.adminNameHint,
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintStyle: const TextStyle(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.adminDuration,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final days in _durations)
                ChoiceChip(
                  label: Text(_durationLabel(days, l10n)),
                  selected: _duration == days,
                  onSelected:
                      _issuing ? null : (_) => setState(() => _duration = days),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          GlassButton(
            label: _issuing ? l10n.adminIssuing : l10n.adminIssue,
            icon: Icons.add_circle_outline_rounded,
            loading: _issuing,
            onTap: _issuing ? () {} : _issue,
          ),
        ],
      ),
    );
  }

  Widget _issuedCard(AccessKey key, BuildContext context, AppLocalizations l10n) {
    final code = key.code ?? '—';
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      color: AppColors.success.withValues(alpha: 0.08),
      borderColor: AppColors.success.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                l10n.adminCodeIssued,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: l10n.adminCopyCode,
                  icon: Icons.copy_rounded,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.commonCopied)),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keysList(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<List<AccessKey>>(
      future: _keysFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l10n.adminLoadFailed('${snapshot.error}'),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5),
            ),
          );
        }

        final keys = snapshot.data ?? const <AccessKey>[];
        if (keys.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l10n.adminNoKeys,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          );
        }

        return Column(
          children: [
            for (final key in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _keyRow(key, context, l10n),
              ),
          ],
        );
      },
    );
  }

  Widget _keyRow(AccessKey key, BuildContext context, AppLocalizations l10n) {
    final code = key.code;
    final statusColor = switch (key.status) {
      'ACTIVE' => AppColors.success,
      'REVOKED' => AppColors.danger,
      _ => AppColors.warning,
    };

    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code ?? key.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  key.expiresAt == null
                      ? '${key.name} · ${l10n.adminLifetime}'
                      : '${key.name} · ${l10n.adminUntil} '
                          '${key.expiresAt!.toIso8601String().substring(0, 10)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              key.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          if (code != null)
            IconButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: code));
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.commonCopied)),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              color: AppColors.textTertiary,
              tooltip: l10n.adminCopy,
            ),
        ],
      ),
    );
  }
}
