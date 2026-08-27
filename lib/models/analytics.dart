/// Analytics overview — users, premium, revenue.
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.totalUsers,
    required this.activePremium,
    required this.blockedUsers,
    required this.revenueUsd,
  });

  final int totalUsers;
  final int activePremium;
  final int blockedUsers;
  final double revenueUsd;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      totalUsers: json['totalUsers'] as int,
      activePremium: json['activePremium'] as int,
      blockedUsers: json['blockedUsers'] as int,
      revenueUsd: (json['revenueUsd'] as num).toDouble(),
    );
  }
}

/// Daily analytics row.
class AnalyticsDailyRow {
  const AnalyticsDailyRow({
    required this.day,
    required this.users,
  });

  final String day; // ISO date string YYYY-MM-DD
  final int users;

  factory AnalyticsDailyRow.fromJson(Map<String, dynamic> json) {
    return AnalyticsDailyRow(
      day: json['day'] as String,
      users: json['users'] as int,
    );
  }
}
