import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_dashboard.dart';
import '../models/analytics.dart';
import '../models/banner_stats.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Admin dashboard overview.
final adminDashboardProvider =
    AsyncNotifierProvider<AdminDashboardNotifier, AdminDashboard?>(
  AdminDashboardNotifier.new,
);

class AdminDashboardNotifier extends AsyncNotifier<AdminDashboard?> {
  @override
  Future<AdminDashboard?> build() async {
    try {
      return await ref.watch(adminRepositoryProvider).getDashboard();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Admin dashboard unavailable: $e',
          source: 'api');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
          await ref.read(adminRepositoryProvider).getDashboard());
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Admin dashboard refresh failed: $e',
          source: 'api');
      state = const AsyncData(null);
    }
  }
}

/// Analytics overview (users, premium, revenue).
final analyticsOverviewProvider =
    AsyncNotifierProvider<AnalyticsOverviewNotifier, AnalyticsOverview?>(
  AnalyticsOverviewNotifier.new,
);

class AnalyticsOverviewNotifier extends AsyncNotifier<AnalyticsOverview?> {
  @override
  Future<AnalyticsOverview?> build() async {
    try {
      return await ref.watch(adminRepositoryProvider).getAnalyticsOverview();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Analytics overview unavailable: $e',
          source: 'api');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
          await ref.read(adminRepositoryProvider).getAnalyticsOverview());
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Analytics overview refresh failed: $e',
          source: 'api');
      state = const AsyncData(null);
    }
  }
}

/// Daily analytics (signups per day).
final analyticsDailyProvider =
    AsyncNotifierProvider<AnalyticsDailyNotifier, List<AnalyticsDailyRow>>(
  AnalyticsDailyNotifier.new,
);

class AnalyticsDailyNotifier extends AsyncNotifier<List<AnalyticsDailyRow>> {
  @override
  Future<List<AnalyticsDailyRow>> build() async {
    try {
      return await ref.watch(adminRepositoryProvider).getAnalyticsDaily();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Analytics daily unavailable: $e',
          source: 'api');
      return const [];
    }
  }

  Future<void> refresh({int days = 7}) async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
          await ref.read(adminRepositoryProvider).getAnalyticsDaily(days: days));
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Analytics daily refresh failed: $e',
          source: 'api');
      state = const AsyncData([]);
    }
  }
}

/// Banner statistics (impressions, clicks, CTR).
final bannerStatsProvider =
    AsyncNotifierProvider<BannerStatsNotifier, BannerStats?>(
  BannerStatsNotifier.new,
);

class BannerStatsNotifier extends AsyncNotifier<BannerStats?> {
  @override
  Future<BannerStats?> build() async {
    try {
      return await ref.watch(adminRepositoryProvider).getBannerStats();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Banner stats unavailable: $e',
          source: 'api');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
          await ref.read(adminRepositoryProvider).getBannerStats());
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Banner stats refresh failed: $e',
          source: 'api');
      state = const AsyncData(null);
    }
  }
}
