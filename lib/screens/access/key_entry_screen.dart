import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../l10n/app_localizations.dart';
import '../../models/key_input.dart';
import '../../providers/access_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/device_providers.dart';
import '../../providers/manual_key_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// "I have a key" — the fastest path to a working connection.
///
/// Accepts three things on purpose:
///  * a Nexa code (NEXA-XXXX-XXXX), redeemed through the backend;
///  * a third-party `vless://` link, stored locally and never uploaded;
///  * an `https://` subscription link, which most providers hand out instead
///    of a bare share link — fetched on the device, contents never uploaded.
///
/// None of these require an account.
class KeyEntryScreen extends ConsumerStatefulWidget {
  const KeyEntryScreen({super.key});

  @override
  ConsumerState<KeyEntryScreen> createState() => _KeyEntryScreenState();
}

class _KeyEntryScreenState extends ConsumerState<KeyEntryScreen> {
  final _controller = TextEditingController();
  KeyInput _parsed = KeyInput.parse('');
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _parsed = KeyInput.parse(_controller.text);
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  /// Maps backend error codes to a sentence the user can act on.
  String _messageFor(AppLocalizations l10n, ApiException e) {
    if (e.isNetworkError) return l10n.errorNetwork;
    final raw = e.message.toUpperCase();
    if (raw.contains('CODE_NOT_FOUND')) return l10n.keyEntryErrorNotFound;
    if (raw.contains('CODE_REVOKED')) return l10n.keyEntryErrorRevoked;
    if (raw.contains('CODE_EXPIRED')) return l10n.keyEntryErrorExpired;
    if (raw.contains('CODE_ALREADY_USED')) return l10n.keyEntryErrorUsed;
    if (raw.contains('INVALID_CODE_FORMAT')) return l10n.keyEntryErrorUnknown;
    return e.message;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final input = KeyInput.parse(_controller.text);

    if (_controller.text.trim().isEmpty) {
      setState(() => _error = l10n.keyEntryErrorEmpty);
      return;
    }
    if (!input.isValid) {
      final lower = _controller.text.trim().toLowerCase();
      final otherScheme = ['vmess://', 'trojan://', 'ss://', 'socks://']
          .any(lower.startsWith);
      setState(() => _error = otherScheme
          ? l10n.keyEntryErrorUnsupportedScheme
          : l10n.keyEntryErrorUnknown);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (input.kind == KeyInputKind.subscriptionUrl) {
        // Provider subscription: download, then import every VLESS profile.
        final profiles =
            await ref.read(subscriptionFetcherProvider).fetch(input.value);
        final count =
            await ref.read(manualKeysProvider.notifier).addAll(profiles);
        if (!mounted) return;
        _controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.keyEntrySuccessSubscription(count))),
        );
      } else if (input.kind == KeyInputKind.vlessUri) {
        // Third-party key: local import, no network call.
        await ref.read(manualKeysProvider.notifier).add(input);
        if (!mounted) return;
        _controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.keyEntrySuccessVless)),
        );
      } else {
        final deviceId = await ref.read(deviceIdProvider.future);
        await ref
            .read(accessRepositoryProvider)
            .redeemCode(input.value, deviceId: deviceId);
        await ref.read(accessKeysProvider.notifier).refresh();
        if (!mounted) return;
        _controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.keyEntrySuccessNexa)),
        );
        context.go('/access');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _messageFor(l10n, e));
    } on AppException catch (e) {
      // Subscription failures already carry a user-facing message.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorUnexpected);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final imported = ref.watch(manualKeysProvider);

    return AppPage(
      title: l10n.keyEntryTitle,
      subtitle: l10n.keyEntrySubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  minLines: 1,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.keyEntryLabel,
                    hintText: l10n.keyEntryHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (_parsed.isValid) _KindChip(input: _parsed, l10n: l10n),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _busy ? null : _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: Text(
                        l10n.keyEntryPasteFromClipboard,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GlassButton(
                  label: l10n.keyEntryActivate,
                  icon: Icons.vpn_key_rounded,
                  loading: _busy,
                  onTap: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.push('/premium'),
              child: Text(
                '${l10n.keyEntryNoKeyYet} ${l10n.keyEntryBuyInstead}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBright,
                ),
              ),
            ),
          ),
          if (imported.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              l10n.keyEntryImportedTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.keyEntryLocalOnly,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            for (final key in imported)
              GlassContainer(
                borderRadius: BorderRadius.circular(16),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.vpn_key_outlined,
                      size: 18,
                      color: AppColors.primaryBright,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            key.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            key.host,
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
                    IconButton(
                      tooltip: l10n.keyEntryRemove,
                      onPressed: () => ref
                          .read(manualKeysProvider.notifier)
                          .remove(key.uri),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.input, required this.l10n});

  final KeyInput input;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isNexa = input.kind == KeyInputKind.nexaCode;
    final color = isNexa ? AppColors.premium : AppColors.primaryBright;

    final (icon, label) = switch (input.kind) {
      KeyInputKind.nexaCode => (
          Icons.workspace_premium_rounded,
          l10n.keyEntryDetectedNexa,
        ),
      KeyInputKind.subscriptionUrl => (
          Icons.cloud_download_rounded,
          l10n.keyEntryDetectedSubscription,
        ),
      _ => (Icons.public_rounded, l10n.keyEntryDetectedVless),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
