/// Log severity levels.
enum LogLevel { debug, info, warning, error }

/// A single buffered log entry.
class AppLogEntry {
  const AppLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.source = 'app',
  });

  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String source;

  String get levelLabel => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARN',
        LogLevel.error => 'ERROR',
      };
}
