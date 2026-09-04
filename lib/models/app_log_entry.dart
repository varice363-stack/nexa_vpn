/// Logging level.
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A single log entry.
class AppLogEntry {
  const AppLogEntry({
    required this.level,
    required this.message,
    required this.source,
    required this.timestamp,
  });

  final LogLevel level;
  final String message;
  final String source;
  final DateTime timestamp;

  @override
  String toString() => '[${level.name.toUpperCase()}] [$source] $message';
}
