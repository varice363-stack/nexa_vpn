/// Live connection metrics emitted by [ConnectionManager].
class ConnectionStats {
  const ConnectionStats({
    this.status,
    this.duration = Duration.zero,
    this.bytesDown = 0,
    this.bytesUp = 0,
    this.speedDown = 0,
    this.speedUp = 0,
    this.startedAt,
  });

  final DateTime? startedAt;
  final Duration duration;
  final int bytesDown;
  final int bytesUp;
  final double speedDown; // Mbps
  final double speedUp; // Mbps

  /// Convenience for the stats widgets: status is attached by the UI layer.
  final dynamic status;

  ConnectionStats copyWith({
    Duration? duration,
    int? bytesDown,
    int? bytesUp,
    double? speedDown,
    double? speedUp,
    DateTime? startedAt,
  }) {
    return ConnectionStats(
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      bytesDown: bytesDown ?? this.bytesDown,
      bytesUp: bytesUp ?? this.bytesUp,
      speedDown: speedDown ?? this.speedDown,
      speedUp: speedUp ?? this.speedUp,
      status: status,
    );
  }
}
