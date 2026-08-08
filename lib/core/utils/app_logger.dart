import 'dart:async';
import 'dart:collection';

import '../../core/constants/app_constants.dart';
import '../../models/app_log_entry.dart';

/// In-memory ring-buffer logger powering the Logs screen.
///
/// Production note: replace/augment with a file-based sink (e.g. `logging` +
/// rotating file writer) when a remote diagnostics pipeline is designed.
class AppLogger {
  AppLogger({int capacity = AppConstants.maxLogEntries})
      : _capacity = capacity;

  final int _capacity;
  final ListQueue<AppLogEntry> _entries = ListQueue();
  final StreamController<AppLogEntry> _controller =
      StreamController.broadcast();

  /// Snapshot of all buffered entries, oldest first.
  List<AppLogEntry> get entries => _entries.toList();

  Stream<AppLogEntry> get stream => _controller.stream;

  void debug(String message, {String source = 'app'}) =>
      _push(LogLevel.debug, message, source);

  void info(String message, {String source = 'app'}) =>
      _push(LogLevel.info, message, source);

  void warn(String message, {String source = 'app'}) =>
      _push(LogLevel.warning, message, source);

  void error(String message, {String source = 'app', Object? error}) =>
      _push(
        LogLevel.error,
        error == null ? message : '$message — $error',
        source,
      );

  void clear() {
    _entries.clear();
  }

  void _push(LogLevel level, String message, String source) {
    final entry = AppLogEntry(
      level: level,
      message: message,
      source: source,
      timestamp: DateTime.now(),
    );
    if (_entries.length >= _capacity) _entries.removeFirst();
    _entries.addLast(entry);
    if (!_controller.isClosed) _controller.add(entry);
  }

  void dispose() => _controller.close();
}
