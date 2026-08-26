import 'dart:async';

import 'app_logger.dart';

/// Retry helper with exponential backoff.
///
/// Attempts up to [maxAttempts] times with delays: 1s, 2s, 4s, 8s...
/// Retries on [shouldRetry] predicate (default: always retry).
/// Logs each attempt via [logger].
Future<T> retry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  bool Function(Object error)? shouldRetry,
  AppLogger? logger,
}) async {
  Object? lastError;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;

      // Don't retry if predicate says so.
      if (shouldRetry != null && !shouldRetry(error)) {
        rethrow;
      }

      // Last attempt — give up.
      if (attempt == maxAttempts) {
        logger?.warn(
          'Retry exhausted after $maxAttempts attempts: $error',
          source: 'retry',
        );
        rethrow;
      }

      // Calculate delay: initialDelay * 2^(attempt-1).
      final delay = Duration(
        milliseconds: initialDelay.inMilliseconds * (1 << (attempt - 1)),
      );

      logger?.info(
        'Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms: $error',
        source: 'retry',
      );

      await Future.delayed(delay);
    }
  }

  // Unreachable, but compiler needs it.
  throw lastError ?? Exception('Retry failed');
}
