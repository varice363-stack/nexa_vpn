import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_log_entry.dart';
import 'app_providers.dart';

/// Live log stream: emits the current buffer on every new entry.
final logsProvider = StreamProvider<List<AppLogEntry>>(
  (ref) async* {
    final logger = ref.watch(loggerProvider);
    yield logger.entries;
    await for (final _ in logger.stream) {
      yield logger.entries;
    }
  },
);
