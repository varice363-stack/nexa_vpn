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
    this.active = true,
  });

  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? buttonText;
  final bool active;

  factory PromoBanner.fromJson(Map<String, Object?> json) {
    return PromoBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      buttonText: json['buttonText'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}
