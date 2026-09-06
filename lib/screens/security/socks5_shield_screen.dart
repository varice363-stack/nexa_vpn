import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/security/socks5_shield_indicator.dart';
import '../../services/security/socks5_scanner.dart';

/// Экран SOCKS5 Shield — уникальная фишка приложения.
///
/// Это ЕДИНСТВЕННЫЙ VPN, который защищает локальный SOCKS5 прокси
/// паролем. Ни одно другое приложение этого не делает.
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
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _scanResults = null;
      _scanError = null;
    });

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
        setState(() {
          _scanError = e.toString();
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'SOCKS5 Shield',
      subtitle: 'Эксклюзивная защита',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Главный блок с индикатором защиты
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
                  'Ваш SOCKS5 защищён',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nexa VPN — единственный VPN, который защищает\nлокальный SOCKS5 прокси паролем',
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

          // Что такое SOCKS5?
          _buildInfoCard(
            icon: Icons.question_answer_rounded,
            title: 'Что такое SOCKS5?',
            description:
                'SOCKS5 — это локальный прокси, через который VPN пропускает '
                'весь ваш трафик. Каждое VPN-приложение создаёт такой прокси, '
                'но большинство оставляет его без защиты.',
          ),

          const SizedBox(height: 12),

          // В чём риск?
          _buildInfoCard(
            icon: Icons.warning_amber_rounded,
            title: 'В чём опасность?',
            description:
                'Незащищённый SOCKS5 позволяет ЛЮБОМУ приложению на вашем '
                'устройстве обойти VPN и раскрыть ваш настоящий IP-адрес. '
                'Это могут использовать шпионы и вредоносные программы.',
          ),

          const SizedBox(height: 12),

          // Как мы защищаем
          _buildInfoCard(
            icon: Icons.shield_rounded,
            title: 'Защита Nexa Shield',
            description:
                'Мы добавляем парольную аутентификацию к SOCKS5 и отключаем UDP. '
                'Каждая сессия получает уникальный случайный пароль, '
                'который знает только ваше устройство.',
            highlight: true,
          ),

          const SizedBox(height: 24),

          // Результаты сканирования
          if (_scanResults != null) ...[
            const Text(
              'Результаты проверки устройства',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Сводка
            Builder(
              builder: (context) {
                final openPorts = _scanResults!.where((r) => r.isOpen).length;
                final vulnPorts = _scanResults!.where((r) => r.isVulnerable).length;
                if (vulnPorts == 0) {
                  return GlassContainer(
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Все порты безопасны ($openPorts из ${_scanResults!.length} проверены)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return GlassContainer(
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.withValues(alpha: 0.05),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.dangerous, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Обнаружено $vulnPorts уязвимых порта! Требуется защита.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ..._scanResults!.map((result) => _buildPortResult(result)),
            const SizedBox(height: 16),
          ],

          // Ошибка сканирования
          if (_scanError != null) ...[
            const SizedBox(height: 12),
            GlassContainer(
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.all(12),
              color: Colors.red.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ошибка проверки: $_scanError',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Кнопка повторного сканирования
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _scan,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_isScanning ? 'Проверяем...' : 'Проверить устройство'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary),
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
                  style: const TextStyle(
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
    final isProtected = result.isOpen && result.isAuthenticated;

    return GlassContainer(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isClosed
                ? Icons.check_circle_rounded
                : isProtected
                    ? Icons.shield_rounded
                    : Icons.dangerous_rounded,
            color: isClosed
                ? Colors.green
                : isProtected
                    ? Colors.blue
                    : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Порт ${result.port}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (result.processName != null)
                  Text(
                    result.processName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            isClosed
                ? 'Закрыт ✓'
                : isProtected
                    ? 'Защищён'
                    : 'Уязвим!',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isClosed
                  ? Colors.green
                  : isProtected
                      ? Colors.blue
                      : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
