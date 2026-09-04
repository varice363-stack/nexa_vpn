import '../domain/repositories/admin_repository.dart';
import '../models/admin_dashboard.dart';
import '../models/analytics.dart';
import '../models/banner_stats.dart';
import '../services/api/api_client.dart';

/// Admin repository backed by the backend API.
class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<AdminDashboard> getDashboard() async {
    final data = await _api.get('/admin/dashboard');
    return AdminDashboard.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<AnalyticsOverview> getAnalyticsOverview() async {
    final data = await _api.get('/analytics/overview');
    return AnalyticsOverview.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<AnalyticsDailyRow>> getAnalyticsDaily({int days = 7}) async {
    final data = await _api.get('/analytics/daily?days=$days');
    return (data as List<dynamic>)
        .map((e) => AnalyticsDailyRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<BannerStats> getBannerStats() async {
    final data = await _api.get('/banners/stats');
    return BannerStats.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
