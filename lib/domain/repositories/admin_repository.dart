import '../../models/admin_dashboard.dart';
import '../../models/analytics.dart';
import '../../models/banner_stats.dart';

/// Admin repository — dashboard, analytics, banner stats.
abstract class AdminRepository {
  /// GET /admin/dashboard — aggregate overview.
  Future<AdminDashboard> getDashboard();

  /// GET /analytics/overview — users, premium, revenue.
  Future<AnalyticsOverview> getAnalyticsOverview();

  /// GET /analytics/daily?days=N — daily signups.
  Future<List<AnalyticsDailyRow>> getAnalyticsDaily({int days = 7});

  /// GET /banners/stats — banner performance with CTR.
  Future<BannerStats> getBannerStats();
}
