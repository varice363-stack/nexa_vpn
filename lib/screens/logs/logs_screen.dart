import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_log_entry.dart';
import '../../providers/app_providers.dart';
import '../../providers/logs_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_container.dart';

/// Diagnostic event log with level filtering and clipboard export.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  LogLevel? _filter;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logsProvider);
    final logs = logsAsync.value ?? const <AppLogEntry>[];
    final visible = _filter == null
        ? logs
        : logs.where((e) => e.level == _filter).toList();

    return AppPage(
      title: 'Logs',
      subtitle: '${logs.length} events in buffer',
      actions: [
        GlassContainer(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(11),
          child: GestureDetector(
            onTap: _copyAll,
            child: const Icon(
              Icons.copy_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level filter chips.
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                active: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final level in LogLevel.values)
                _FilterChip(
                  label: level.name.toUpperCase(),
                  active: _filter == level,
                  color: _levelColor(level),
                  onTap: () => setState(() => _filter = level),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No log entries',
              message: 'Events will appear here as they happen.',
            )
          else
            for (final entry in visible)
              _LogRow(entry: entry),
          if (visible.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () {
                  ref.read(loggerProvider).clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs cleared')),
                  );
                },
                child: const Text(
                  'Clear logs',
                  style: TextStyle(fontSize: 12.5, color: AppColors.danger),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _copyAll() async {
    final logs = ref.read(logsProvider).value ?? const <AppLogEntry>[];
    final text = logs
        .map((e) =>
            '[${e.timestamp.toIso8601String()}] ${e.levelLabel} ${e.source}: ${e.message}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.debug => AppColors.textSecondary,
        LogLevel.info => AppColors.primaryBright,
        LogLevel.warning => AppColors.warning,
        LogLevel.error => AppColors.danger,
      };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : Colors.white.withValues(alpha: 0.05),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : (color ?? AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.debug => AppColors.textSecondary,
      LogLevel.info => AppColors.primaryBright,
      LogLevel.warning => AppColors.warning,
      LogLevel.error => AppColors.danger,
    };

    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.levelLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.source,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _time(entry.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
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

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
