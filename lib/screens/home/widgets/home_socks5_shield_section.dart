import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';
import '../../../services/security/socks5_scanner.dart';

/// Главная фишка приложения — SOCKS5 Shield на главном экране.
///
/// Показывает статус защиты: сканирует порты и показывает
/// результат одним взглядом. При нажатии — открывает подробную информацию.
class HomeSocks5ShieldSection extends ConsumerStatefulWidget {
  const HomeSocks5ShieldSection({super.key});

  @override
  ConsumerState<HomeSocks5ShieldSection> createState() =>
      _HomeSocks5ShieldSectionState();
}

class _HomeSocks5ShieldSectionState extends ConsumerState<HomeSocks5ShieldSection> {
  final _scanner = const Socks5Scanner();
  _ScanState _state = _ScanState.initial;
  int _vulnerablePorts = 0;
  int _totalPorts = 0;
  bool _scanning = false;

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    try {
      final results = await _scanner.scan();
      final vulnerable = results.where((r) => r.isVulnerable).length;
      if (mounted) {
        setState(() {
          _vulnerablePorts = vulnerable;
          _totalPorts = results.length;
          _state = vulnerable == 0 ? _ScanState.protected : _ScanState.vulnerable;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _scanning = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/socks5-shield'),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Shield icon with status color
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: _shieldGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _shieldColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _shieldIcon,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SOCKS5 Shield',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _shieldColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _shieldColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _statusBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _shieldColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_scanning) ...[
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Color get _shieldColor {
    switch (_state) {
      case _ScanState.initial:
      case _ScanState.protected:
        return Colors.green;
      case _ScanState.vulnerable:
        return Colors.red;
      case _ScanState.error:
        return AppColors.warning;
    }
  }

  IconData get _shieldIcon {
    switch (_state) {
      case _ScanState.initial:
        return Icons.shield_rounded;
      case _ScanState.protected:
        return Icons.shield_rounded;
      case _ScanState.vulnerable:
        return Icons.gpp_bad_rounded;
      case _ScanState.error:
        return Icons.error_outline_rounded;
    }
  }

  Gradient get _shieldGradient {
    switch (_state) {
      case _ScanState.initial:
      case _ScanState.protected:
        return const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case _ScanState.vulnerable:
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case _ScanState.error:
        return LinearGradient(
          colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  String get _statusBadge {
    if (_scanning) return 'СКАНИРОВАНИЕ';
    switch (_state) {
      case _ScanState.initial:
        return 'ПРОВЕРКА';
      case _ScanState.protected:
        return 'ЗАЩИЩЕНО';
      case _ScanState.vulnerable:
        return 'УГРОЗА';
      case _ScanState.error:
        return 'ОШИБКА';
    }
  }

  String get _statusText {
    if (_scanning) return 'Проверяем порты устройства...';
    switch (_state) {
      case _ScanState.initial:
        return 'Проверяем безопасность SOCKS5...';
      case _ScanState.protected:
        return '$_totalPorts портов проверено — все безопасны';
      case _ScanState.vulnerable:
        return 'Обнаружено $_vulnerablePorts уязвимых порта!';
      case _ScanState.error:
        return 'Не удалось выполнить проверку';
    }
  }
}

enum _ScanState {
  initial,
  protected,
  vulnerable,
  error,
}
