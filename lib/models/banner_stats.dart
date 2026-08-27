/// Banner performance stats (impressions, clicks, CTR).
class BannerStats {
  const BannerStats({
    required this.totals,
    required this.banners,
  });

  final BannerStatsTotals totals;
  final List<BannerStatItem> banners;

  factory BannerStats.fromJson(Map<String, dynamic> json) {
    return BannerStats(
      totals: BannerStatsTotals.fromJson(
          json['totals'] as Map<String, dynamic>),
      banners: (json['banners'] as List<dynamic>)
          .map((e) => BannerStatItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BannerStatsTotals {
  const BannerStatsTotals({
    required this.impressions,
    required this.clicks,
    required this.ctr,
  });

  final int impressions;
  final int clicks;
  final double ctr;

  factory BannerStatsTotals.fromJson(Map<String, dynamic> json) {
    return BannerStatsTotals(
      impressions: json['impressions'] as int,
      clicks: json['clicks'] as int,
      ctr: (json['ctr'] as num).toDouble(),
    );
  }
}

class BannerStatItem {
  const BannerStatItem({
    required this.id,
    required this.title,
    required this.placement,
    required this.active,
    required this.impressions,
    required this.clicks,
    required this.ctr,
  });

  final String id;
  final String title;
  final String placement;
  final bool active;
  final int impressions;
  final int clicks;
  final double ctr;

  factory BannerStatItem.fromJson(Map<String, dynamic> json) {
    return BannerStatItem(
      id: json['id'] as String,
      title: json['title'] as String,
      placement: json['placement'] as String,
      active: json['active'] as bool,
      impressions: json['impressions'] as int,
      clicks: json['clicks'] as int,
      ctr: (json['ctr'] as num).toDouble(),
    );
  }
}
