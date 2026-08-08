/// A completed VPN session, persisted for the statistics screen.
class ConnectionSession {
  const ConnectionSession({
    required this.serverId,
    required this.serverName,
    required this.startedAt,
    required this.endedAt,
    required this.bytesDown,
    required this.bytesUp,
  });

  final String serverId;
  final String serverName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int bytesDown;
  final int bytesUp;

  Duration get duration => endedAt.difference(startedAt);

  factory ConnectionSession.fromJson(Map<String, Object?> json) {
    return ConnectionSession(
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      bytesDown: (json['bytesDown'] as num).toInt(),
      bytesUp: (json['bytesUp'] as num).toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'serverId': serverId,
      'serverName': serverName,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'bytesDown': bytesDown,
      'bytesUp': bytesUp,
    };
  }
}
