import '../../core/errors/app_exception.dart';

/// Backend communication error.
class ApiException extends AppException {
  const ApiException(super.message, {super.code, this.statusCode});

  /// HTTP status code, or `null` for transport-level failures.
  final int? statusCode;

  /// True for transport failures (no network, timeout) — used by
  /// repositories to decide whether a local fallback is appropriate.
  bool get isNetworkError => code == 'NETWORK' || code == 'TIMEOUT';
}
