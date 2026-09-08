import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';
import '../../core/utils/retry.dart';
import '../security/ssl_pinning_service.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Minimal JSON HTTP client for the Morok VPN backend.
///
/// Features:
/// - JWT injection
/// - UTF-8 response decoding
/// - Retry on network/timeout errors only
/// - 401 auto-logout
/// - Rate limiting (500ms между запросами)
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    AppLogger? logger,
    http.Client? httpClient,
    SslPinningService? sslPinningService,
  })  : _tokenStorage = tokenStorage,
        _logger = logger,
        _client = httpClient ?? http.Client(),
        _sslPinningService = sslPinningService ?? SslPinningService(logger),
        _baseUrl = ApiConfig.resolvedBaseUrl;

  final TokenStorage _tokenStorage;
  final AppLogger? _logger;
  final http.Client _client;
  final SslPinningService _sslPinningService;
  final String _baseUrl;

  /// Rate limiting: минимальный интервал между запросами.
  static const _minRequestInterval = Duration(milliseconds: 500);
  DateTime? _lastRequestTime;

  /// Callback для logout при 401.
  VoidCallback? onUnauthorized;

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  /// Rate-limited HTTP request с retry на сетевые ошибки.
  Future<dynamic> _request(String method, String path, {Object? body}) async {
    // Rate limiting
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future<void>.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();

    final uri = Uri.parse('$_baseUrl$path');

    // SSL pinning (не блокирует если пины не настроены)
    try {
      await _sslPinningService.validateBeforeRequest(_baseUrl);
    } on SslPinningValidationException catch (e) {
      _logger?.error('SSL validation failed: ${e.message}', source: 'api');
      throw const ApiException(
        'Connection security validation failed',
        code: 'SSL_VALIDATION_FAILED',
      );
    }

    final token = await _tokenStorage.read();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };

    _logger?.debug('$method $path', source: 'api');

    return await retry(
      () => _executeRequest(method, uri, headers, body),
      maxAttempts: 3,
      shouldRetry: (error) {
        if (error is ApiException) {
          return error.isNetworkError || error.code == 'TIMEOUT';
        }
        return error is TimeoutException || error is http.ClientException;
      },
      logger: _logger,
    );
  }

  Future<dynamic> _executeRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    late http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client.get(uri, headers: headers)
            .timeout(ApiConfig.timeout),
        'POST' => await _client
            .post(uri, headers: headers, body: _encode(body))
            .timeout(ApiConfig.timeout),
        'PATCH' => await _client
            .patch(uri, headers: headers, body: _encode(body))
            .timeout(ApiConfig.timeout),
        'DELETE' => await _client
            .delete(uri, headers: headers)
            .timeout(ApiConfig.timeout),
        _ => throw ApiException('Unsupported method: $method',
            code: 'BAD_REQUEST'),
      };
    } on TimeoutException {
      throw const ApiException('Request timed out', code: 'TIMEOUT');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Request failed: $e', code: 'NETWORK');
    }

    final decoded = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // 401 — сессия истекла
    if (response.statusCode == 401) {
      _logger?.warn('401 Unauthorized — clearing token', source: 'api');
      await _tokenStorage.clear();
      onUnauthorized?.call();
      throw const ApiException(
        'Session expired. Please re-authenticate.',
        statusCode: 401,
        code: 'UNAUTHORIZED',
      );
    }

    final message = _errorMessage(decoded, response.statusCode);
    _logger?.debug('$method ${uri.path} → ${response.statusCode}: $message',
        source: 'api');
    throw ApiException(
      message,
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
    );
  }

  String? _encode(Object? body) => body == null ? null : jsonEncode(body);

  dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(dynamic decoded, int status) {
    if (decoded is Map && decoded['message'] != null) {
      final message = decoded['message'];
      if (message is List) return message.join('; ');
      return message.toString();
    }
    return 'Request failed (HTTP $status)';
  }
}
