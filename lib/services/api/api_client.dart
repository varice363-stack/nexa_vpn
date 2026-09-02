import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';
import '../../core/utils/retry.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Minimal JSON HTTP client for the Nexa VPN backend.
///
/// Injects the stored JWT, decodes UTF-8 responses and maps every failure
/// onto [ApiException] (network, timeout, HTTP status, malformed body).
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    AppLogger? logger,
    http.Client? httpClient,
  })  : _tokenStorage = tokenStorage,
        _logger = logger,
        _client = httpClient ?? http.Client(),
        _baseUrl = ApiConfig.resolvedBaseUrl;

  final TokenStorage _tokenStorage;
  final AppLogger? _logger;
  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final token = await _tokenStorage.read();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };

    _logger?.info('$method $_baseUrl$path (base=$_baseUrl)', source: 'api');
    _logger?.debug('$method $path', source: 'api');

    // Retry только на сетевые ошибки, не на 4xx/5xx.
    return await retry(
      () => _executeRequest(method, uri, headers, body),
      maxAttempts: 3,
      shouldRetry: (error) {
        // Retry только на timeout и network errors.
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

    final message = _errorMessage(decoded, response.statusCode);
    _logger?.warn('$method ${uri.path} → ${response.statusCode}: $message',
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
