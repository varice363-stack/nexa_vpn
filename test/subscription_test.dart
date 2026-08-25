import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexa_vpn/core/errors/app_exception.dart';
import 'package:nexa_vpn/models/key_input.dart';
import 'package:nexa_vpn/services/vpn/subscription_fetcher.dart';

/// Most providers hand out an `https://` subscription link, not a bare
/// `vless://` share link. The app rejected those outright, which turned away
/// exactly the users it is built to win over — someone arriving with a key
/// they already pay for.
///
/// The fixtures below mirror the shape of a real provider response: base64,
/// one `vless://` profile per line, many servers in one link.

const _profileA =
    'vless://11111111-2222-3333-4444-555555555555@a.example:443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=abc&sid=ff&type=tcp&flow=xtls-rprx-vision#Netherlands';

const _profileB =
    'vless://11111111-2222-3333-4444-555555555555@b.example:8443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=abc&sid=ff&type=tcp#Germany';

String _base64Body(List<String> lines) =>
    base64.encode(utf8.encode(lines.join('\n')));

void main() {
  group('KeyInput — subscription links are recognised', () {
    test('accepts an https subscription URL', () {
      final input = KeyInput.parse(
        'https://go.example.net/sub/abc123#My%20Provider',
      );
      expect(input.kind, KeyInputKind.subscriptionUrl);
      expect(input.isValid, isTrue);
      expect(input.label, 'My Provider');
    });

    test('accepts http as well as https', () {
      expect(
        KeyInput.parse('http://panel.example/sub/x').kind,
        KeyInputKind.subscriptionUrl,
      );
    });

    test('still recognises a bare vless link', () {
      expect(KeyInput.parse(_profileA).kind, KeyInputKind.vlessUri);
    });

    test('still recognises a Nexa code', () {
      expect(KeyInput.parse('NEXA-7QK2-M4XP').kind, KeyInputKind.nexaCode);
    });

    test('rejects a URL with no host', () {
      expect(KeyInput.parse('https://').kind, KeyInputKind.unknown);
    });
  });

  group('SubscriptionFetcher.parseBody', () {
    test('reads a base64 subscription — the common provider format', () {
      final profiles =
          SubscriptionFetcher.parseBody(_base64Body([_profileA, _profileB]));

      expect(profiles, hasLength(2));
      expect(profiles[0].uri, _profileA);
      expect(profiles[0].label, 'Netherlands');
      expect(profiles[1].label, 'Germany');
    });

    test('reads a plain-text subscription', () {
      final profiles =
          SubscriptionFetcher.parseBody('$_profileA\n$_profileB\n');
      expect(profiles, hasLength(2));
    });

    test('tolerates base64 without padding and with newlines', () {
      final raw = _base64Body([_profileA]).replaceAll('=', '');
      final chunked = '${raw.substring(0, 20)}\n${raw.substring(20)}';

      expect(SubscriptionFetcher.parseBody(chunked), hasLength(1));
    });

    test('keeps the URI byte-for-byte — rewriting breaks a foreign server',
        () {
      final profiles = SubscriptionFetcher.parseBody(_base64Body([_profileA]));
      expect(profiles.single.uri, _profileA);
    });

    test('skips malformed entries instead of failing the whole import', () {
      final body = _base64Body([
        _profileA,
        'vless://missing-host',
        'not a link at all',
        _profileB,
      ]);
      expect(SubscriptionFetcher.parseBody(body), hasLength(2));
    });

    test('drops duplicates', () {
      final body = _base64Body([_profileA, _profileA]);
      expect(SubscriptionFetcher.parseBody(body), hasLength(1));
    });

    test('falls back to the host when a profile has no name', () {
      final unnamed = _profileA.split('#').first;
      final profiles = SubscriptionFetcher.parseBody(_base64Body([unnamed]));
      expect(profiles.single.label, 'a.example');
    });

    test('returns nothing for an unrelated payload', () {
      expect(SubscriptionFetcher.parseBody('<html>nope</html>'), isEmpty);
    });
  });

  group('SubscriptionFetcher.fetch', () {
    test('downloads and extracts profiles', () async {
      final fetcher = SubscriptionFetcher(
        client: MockClient(
          (_) async => http.Response(_base64Body([_profileA, _profileB]), 200),
        ),
      );

      final profiles = await fetcher.fetch('https://go.example.net/sub/abc');
      expect(profiles, hasLength(2));
    });

    test('sends a client User-Agent so panels do not serve HTML', () async {
      String? seen;
      final fetcher = SubscriptionFetcher(
        client: MockClient((req) async {
          seen = req.headers['User-Agent'];
          return http.Response(_base64Body([_profileA]), 200);
        }),
      );

      await fetcher.fetch('https://go.example.net/sub/abc');
      expect(seen, isNotNull);
    });

    test('explains an expired link (404) in plain words', () async {
      final fetcher = SubscriptionFetcher(
        client: MockClient((_) async => http.Response('nope', 404)),
      );

      await expectLater(
        fetcher.fetch('https://go.example.net/sub/gone'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    });

    test('explains an empty result rather than silently succeeding', () async {
      final fetcher = SubscriptionFetcher(
        client: MockClient((_) async => http.Response('<html></html>', 200)),
      );

      await expectLater(
        fetcher.fetch('https://go.example.net/sub/html'),
        throwsA(isA<AppException>()),
      );
    });

    test('reports an unreachable server instead of hanging', () async {
      final fetcher = SubscriptionFetcher(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );

      await expectLater(
        fetcher.fetch('https://unreachable.example/sub'),
        throwsA(isA<AppException>()),
      );
    });
  });
}

/// Stand-in for a network failure without importing dart:io in a test.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
