import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../models/connection_session.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/section_header.dart';

/// Usage statistics: totals, weekly bar chart, top countries, history.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final sessions = sessionsAsync.value ?? const <ConnectionSession>[];

    final totalBytes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.bytesDown + s.bytesUp,
    );
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMinutes,
    );

    // Last 7 days buckets.
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final week = List<int>.filled(7, 0);
    for (final s in sessions) {
      final day = dayStart.difference(DateTime(
        s.startedAt.year,
        s.startedAt.month,
        s.startedAt.day,
      )).inDays;
      if (day >= 0 && day < 7) {
        week[6 - day] += (s.bytesDown + s.bytesUp) ~/ (1024 * 1024);
      }
    }
    final maxDay = week.fold<int>(1, (m, v) => v > m ? v : m);

    final byCountry = <String, int>{};
    for (final s in sessions) {
      final country = s.serverName.split('·').first.trim();
      byCountry[country] = (byCountry[country] ?? 0) + 1;
    }
    final topCountries = byCountry.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppPage(
      title: 'Statistics',
      subtitle: sessions.isEmpty
          ? 'No data yet'
          : '${sessions.length} sessions • '
              '${Formatters.bytes(totalBytes)} total',
      actions: [
        GlassContainer(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(11),
          child: GestureDetector(
            onTap: () => ref.read(sessionsProvider.notifier).refresh(),
            child: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Totals.
          Row(
            children: [
              _SummaryTile(
                icon: Icons.data_usage_rounded,
                accent: AppColors.primaryBright,
                value: Formatters.bytes(totalBytes),
                label: 'Total data',
              ),
              const SizedBox(width: 10),
              _SummaryTile(
                icon: Icons.timer_rounded,
                accent: AppColors.success,
                value:
                    '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                label: 'Time online',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'LAST 7 DAYS'),
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                height: week[i] == 0
                                    ? 3
                                    : 8 + (110 * week[i] / maxDay).clamp(8, 102),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: i == 6
                                      ? AppColors.primaryGradient
                                      : LinearGradient(
                                          colors: [
                                            AppColors.primary
                                                .withValues(alpha: 0.55),
                                            AppColors.primary
                                                .withValues(alpha: 0.25),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _dayLabel(dayStart.subtract(
                                  Duration(days: 6 - i),
                                )),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (topCountries.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionHeader(title: 'TOP LOCATIONS'),
            GlassContainer(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (var i = 0; i < topCountries.length && i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              topCountries[i].key,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${topCountries[i].value} '
                            '${topCountries[i].value == 1 ? 'session' : 'sessions'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const SectionHeader(title: 'RECENT SESSIONS'),
          for (final session in sessions.take(8))
            _SessionRow(session: session),
          if (sessions.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(sessionsProvider.notifier).clearHistory(),
                child: const Text(
                  'Clear history',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime d) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return weekdays[d.weekday - 1];
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final ConnectionSession session;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(
            session.serverName.split('·').first.trim()[0],
            style: const TextStyle(fontSize: 20, color: AppColors.primaryBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.serverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.shortDateTime(session.startedAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.duration(session.duration),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Formatters.bytes(session.bytesDown + session.bytesUp),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
