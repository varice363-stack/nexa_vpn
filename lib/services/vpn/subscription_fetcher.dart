import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';

/// One profile pulled out of a subscription.
class SubscriptionProfile {
  const SubscriptionProfile({required this.uri, required this.label});

  final String uri;
  final String label;
}

/// Downloads a provider subscription and extracts the `vless://` profiles.
///
/// Most providers hand out an `https://` subscription link rather than a bare
/// share link, so supporting this is what makes the app usable with a key the
/// customer already has. The body is typically base64 with one profile per
/// line, but plain text is just as common.
///
/// The payload is other people's server credentials: it is parsed on the
/// device and never forwarded to our backend.
class SubscriptionFetcher {
  SubscriptionFetcher({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  /// Fetches [url] and returns every VLESS profile it contains.
  ///
  /// Throws [AppException] with a message meant for the user.
  Future<List<SubscriptionProfile>> fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AppException('That does not look like a valid link.');
    }

    http.Response response;
    try {
      response = await _client.get(
        uri,
        // Some panels serve an HTML landing page unless the request looks
        // like a proxy client.
        headers: const {'User-Agent': 'Nexa/1.0'},
      ).timeout(_timeout);
    } catch (e) {
      throw AppException(
        'Could not reach the subscription server. Check the link and your '
        'internet connection. ($e)',
      );
    }

    if (response.statusCode == 404) {
      throw const AppException(
        'The subscription was not found (404). The link may have expired.',
      );
    }
    if (response.statusCode >= 400) {
      throw AppException(
        'The subscription server returned an error '
        '(${response.statusCode}).',
      );
    }

    final profiles = parseBody(response.body);
    if (profiles.isEmpty) {
      throw const AppException(
        'No VLESS servers were found at that link. It may be a subscription '
        'for a protocol this app does not support yet.',
      );
    }
    return profiles;
  }

  /// Extracts profiles from a subscription body.
  ///
  /// Handles base64 (the common case) and plain text. Kept separate from the
  /// network call so it can be tested without one.
  static List<SubscriptionProfile> parseBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>[trimmed];

    // Base64 payloads arrive with or without padding, sometimes URL-safe.
    final decoded = _tryBase64(trimmed);
    if (decoded != null) candidates.add(decoded);

    for (final candidate in candidates) {
      final found = _extractVless(candidate);
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  static String? _tryBase64(String input) {
    // Strip whitespace/newlines that servers add for readability.
    final compact = input.replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty) return null;
    try {
      final normalised = base64.normalize(
        compact.replaceAll('-', '+').replaceAll('_', '/'),
      );
      return utf8.decode(base64.decode(normalised), allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static List<SubscriptionProfile> _extractVless(String text) {
    final out = <SubscriptionProfile>[];
    final seen = <String>{};

    for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (!line.toLowerCase().startsWith('vless://')) continue;

      final parsed = Uri.tryParse(line);
      // A dialable profile needs a UUID and a host:port.
      if (parsed == null ||
          parsed.userInfo.isEmpty ||
          parsed.host.isEmpty ||
          parsed.port == 0) {
        continue;
      }
      if (!seen.add(line)) continue;

      final label = parsed.fragment.isEmpty
          ? parsed.host
          : Uri.decodeComponent(parsed.fragment);
      out.add(SubscriptionProfile(uri: line, label: label));
    }
    return out;
  }
}
