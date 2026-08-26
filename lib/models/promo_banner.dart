/// Placement slot a banner is rendered in.
enum BannerPlacement {
  home,
  premium;

  static BannerPlacement fromJson(Object? value) {
    return switch (value) {
      'premium' => BannerPlacement.premium,
      _ => BannerPlacement.home,
    };
  }

  String get wireValue => name;
}

/// Promotional banner served by the backend `/banners` endpoint.
///
/// Named `PromoBanner` to avoid clashing with Flutter's Material `Banner`.
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.buttonText,
    this.targetUrl,
    this.placement = BannerPlacement.home,
    this.active = true,
    this.displayDuration = 30,
  });

  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? buttonText;

  /// External destination opened on CTA tap. `null` keeps the legacy
  /// behaviour — in-app navigation to the Premium screen.
  final String? targetUrl;

  final BannerPlacement placement;
  final bool active;

  /// Duration (seconds) this banner stays visible in the carousel.
  /// Per-banner control: one banner can show for 30s, another for 45s.
  final int displayDuration;

  /// True when the CTA should open an external http(s) destination.
  /// Any other scheme is ignored: the payload comes from the network and
  /// must not be able to launch arbitrary intents on the device.
  bool get hasExternalTarget {
    final url = targetUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  factory PromoBanner.fromJson(Map<String, Object?> json) {
    return PromoBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      buttonText: json['buttonText'] as String?,
      targetUrl: json['targetUrl'] as String?,
      placement: BannerPlacement.fromJson(json['placement']),
      active: json['active'] as bool? ?? true,
      displayDuration: (json['displayDuration'] as num?)?.toInt() ?? 30,
    );
  }
}
