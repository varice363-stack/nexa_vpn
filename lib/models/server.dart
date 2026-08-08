/// Immutable VPN server entity.
///
/// Extended with [id] (stable key for lists / selection) and [countryCode]
/// (ISO 3166-1 alpha-2, required for flag rendering) on top of the original
/// contract: country, city, ping, load, premium.
class Server {
  const Server({
    required this.id,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.ping,
    required this.load,
    required this.premium,
  });

  /// Stable unique identifier, e.g. `us-nyc-01`.
  final String id;

  /// Display name of the country, e.g. `United States`.
  final String country;

  /// ISO 3166-1 alpha-2 country code, e.g. `US`.
  final String countryCode;

  /// City / location label, e.g. `New York`.
  final String city;

  /// Latency in milliseconds.
  final int ping;

  /// Current server load in the range `0.0` (idle) .. `1.0` (saturated).
  final double load;

  /// Whether this location requires a Premium subscription.
  final bool premium;

  // ── Derived ──────────────────────────────────────────────────────────────

  /// Flag emoji rendered from [countryCode], e.g. 🇺🇸.
  String get flagEmoji => flagEmojiFor(countryCode);

  /// Flag emoji for an ISO 3166-1 alpha-2 code, e.g. `US` → 🇺🇸.
  static String flagEmojiFor(String countryCode) => _flagEmoji(countryCode);

  String get displayName => '$country · $city';

  int get loadPercent => (load * 100).round();

  /// Case-insensitive search across country, city, code and id.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return country.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q) ||
        countryCode.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q);
  }

  // ── Copy / serialization ────────────────────────────────────────────────

  Server copyWith({
    String? id,
    String? country,
    String? countryCode,
    String? city,
    int? ping,
    double? load,
    bool? premium,
  }) {
    return Server(
      id: id ?? this.id,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      ping: ping ?? this.ping,
      load: load ?? this.load,
      premium: premium ?? this.premium,
    );
  }

  factory Server.fromJson(Map<String, Object?> json) {
    return Server(
      id: json['id'] as String,
      country: json['country'] as String,
      countryCode: json['countryCode'] as String,
      city: json['city'] as String,
      ping: (json['ping'] as num).toInt(),
      load: (json['load'] as num).toDouble(),
      premium: json['premium'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'country': country,
      'countryCode': countryCode,
      'city': city,
      'ping': ping,
      'load': load,
      'premium': premium,
    };
  }

  // ── Identity ────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) => other is Server && other.id == id;

  @override
  int get hashCode => id.hashCode;

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _flagEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌐';
    final buffer = StringBuffer();
    for (final unit in code.codeUnits) {
      if (unit < 0x41 || unit > 0x5A) return '🌐'; // non A–Z letter
      buffer.writeCharCode(0x1F1E6 + (unit - 0x41));
    }
    return buffer.toString();
  }
}
