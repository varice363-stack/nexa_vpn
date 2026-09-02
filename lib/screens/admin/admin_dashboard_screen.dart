import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_dashboard.dart';
import '../../models/analytics.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/banner_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/common/glass_container.dart';

/// Admin dashboard — overview of users, servers, revenue, and banner stats.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.surface.withValues(alpha: 0.5),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.adminDashboard,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.adminDashboardSubtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // TabBar
              Container(
                color: AppColors.surface.withValues(alpha: 0.3),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: [
                    Tab(text: l10n.adminTabOverview),
                    Tab(text: l10n.adminTabBanners),
                    Tab(text: l10n.adminTabAnalytics),
                  ],
                ),
              ),
              // Tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    const _OverviewTab(),
                    const _BannersTab(),
                    const _AnalyticsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overview tab — users, servers, revenue summary.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final analyticsAsync = ref.watch(analyticsOverviewProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(adminDashboardProvider.notifier).refresh();
        await ref.read(analyticsOverviewProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildDashboardCard(context, l10n, dashboardAsync),
          const SizedBox(height: 16),
          _buildAnalyticsCard(context, l10n, analyticsAsync),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<AdminDashboard?> async,
  ) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminOverview,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (async.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (async.hasError)
            Text(l10n.commonError,
                style: const TextStyle(color: AppColors.danger))
          else if (async.value == null)
            Text(l10n.adminNoData,
                style: const TextStyle(color: AppColors.textSecondary))
          else
            _buildOverviewGrid(l10n, async.value!),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(AppLocalizations l10n, AdminDashboard data) {
    return Column(
      children: [
        Row(
          children: [
            _StatTile(
              icon: Icons.people,
              label: l10n.adminTotalUsers,
              value: '${data.users.total}',
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: Icons.person_add,
              label: l10n.adminNewToday,
              value: '+${data.users.newToday}',
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(
              icon: Icons.workspace_premium,
              label: l10n.adminActivePremium,
              value: '${data.users.activePremium}',
              color: AppColors.premium,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: Icons.dns,
              label: l10n.adminActiveServers,
              value: '${data.servers.active}',
              color: AppColors.cyan,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<AnalyticsOverview?> async,
  ) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminRevenue,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (async.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (async.hasError)
            Text(l10n.commonError,
                style: const TextStyle(color: AppColors.danger))
          else if (async.value == null)
            Text(l10n.adminNoData,
                style: const TextStyle(color: AppColors.textSecondary))
          else
            _buildRevenueStats(l10n, async.value!),
        ],
      ),
    );
  }

  Widget _buildRevenueStats(AppLocalizations l10n, AnalyticsOverview data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: l10n.adminTotalRevenue,
                value: '\$${data.revenueUsd.toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatTile(
              icon: Icons.block,
              label: l10n.adminBlockedUsers,
              value: '${data.blockedUsers}',
              color: AppColors.danger,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: Icons.star,
              label: l10n.adminPremiumUsers,
              value: '${data.activePremium}',
              color: AppColors.premium,
            ),
          ],
        ),
      ],
    );
  }
}

/// Banners tab — impressions, clicks, CTR.
class _BannersTab extends ConsumerWidget {
  const _BannersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(bannerStatsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(bannerStatsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildCreateBannerButton(context, l10n),
          const SizedBox(height: 16),
          _buildTotalsCard(context, l10n, statsAsync),
          const SizedBox(height: 16),
          _buildBannersList(context, l10n, statsAsync),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCreateBannerButton(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => context.push('/admin/create-banner'),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.adminCreateBanner,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.adminCreateBannerSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsCard(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<dynamic> async,
  ) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminBannerTotals,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (async.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (async.hasError)
            Text(l10n.commonError,
                style: const TextStyle(color: AppColors.danger))
          else if (async.value == null)
            Text(l10n.adminNoData,
                style: const TextStyle(color: AppColors.textSecondary))
          else
            _buildTotalsGrid(l10n, async.value),
        ],
      ),
    );
  }

  Widget _buildTotalsGrid(AppLocalizations l10n, dynamic stats) {
    final totals = stats.totals;
    return Row(
      children: [
        _StatTile(
          icon: Icons.visibility,
          label: l10n.adminImpressions,
          value: _formatNumber(totals.impressions),
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.touch_app,
          label: l10n.adminClicks,
          value: _formatNumber(totals.clicks),
          color: AppColors.success,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.trending_up,
          label: 'CTR',
          value: '${totals.ctr.toStringAsFixed(2)}%',
          color: AppColors.premium,
        ),
      ],
    );
  }

  Widget _buildBannersList(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<dynamic> async,
  ) {
    if (async.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (async.hasError || async.value == null) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.adminNoData,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final banners = async.value.banners as List<dynamic>;
    if (banners.isEmpty) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.adminNoBanners,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminAllBanners,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...banners.map((b) => _BannerStatCard(banner: b, l10n: l10n)),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Analytics tab — daily signups chart.
class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dailyAsync = ref.watch(analyticsDailyProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(analyticsDailyProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminDailySignups,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (dailyAsync.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (dailyAsync.hasError)
                  Text(l10n.commonError,
                      style: const TextStyle(color: AppColors.danger))
                else if (dailyAsync.value?.isEmpty ?? true)
                  Text(l10n.adminNoData,
                      style: const TextStyle(color: AppColors.textSecondary))
                else
                  _DailyChart(data: dailyAsync.value!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─ Helper widgets ──────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStatCard extends ConsumerWidget {
  const _BannerStatCard({required this.banner, required this.l10n});

  final dynamic banner;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = banner.active ? AppColors.success : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    banner.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  banner.placement,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка активации/деактивации
                GestureDetector(
                  onTap: () => _toggleActive(ref, banner.id, banner.active),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: banner.active 
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: banner.active 
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      banner.active ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: banner.active ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(
                  icon: Icons.visibility,
                  value: '${banner.impressions}',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  icon: Icons.touch_app,
                  value: '${banner.clicks}',
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  icon: Icons.trending_up,
                  value: '${banner.ctr.toStringAsFixed(1)}%',
                  color: AppColors.premium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleActive(WidgetRef ref, String bannerId, bool currentlyActive) async {
    try {
      if (currentlyActive) {
        await ref.read(bannerRepositoryProvider).deactivateBanner(bannerId);
      } else {
        await ref.read(bannerRepositoryProvider).activateBanner(bannerId);
      }
      // Обновляем список баннеров
      ref.read(bannerStatsProvider.notifier).refresh();
    } catch (e) {
      // Ошибка обработана в repository
    }
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.data});

  final List<AnalyticsDailyRow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxUsers = data.map((d) => d.users).reduce((a, b) => a > b ? a : b);
    final chartHeight = 150.0;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final row in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${row.users}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxUsers > 0
                          ? (row.users / maxUsers) * chartHeight
                          : 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.6),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      row.day.substring(5),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
