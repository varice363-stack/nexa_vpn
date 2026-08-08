/// Base application exception with a stable error code.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

/// Thrown when a feature requires infrastructure that is not yet wired
/// (billing, push, native tunnel, backend API).
class NotImplementedInfrastructureException extends AppException {
  const NotImplementedInfrastructureException(String feature)
      : super('$feature requires external infrastructure and is not wired yet',
            code: 'EXT-INFRA');
}
