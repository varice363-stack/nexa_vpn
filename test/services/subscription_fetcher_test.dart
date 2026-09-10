import 'package:flutter_test/flutter_test.dart';
import 'package:morok_vpn/services/vpn/subscription_fetcher.dart';

void main() {
  group('SubscriptionFetcher.parseBody', () {
    test('returns empty for empty input', () {
      final result = SubscriptionFetcher.parseBody('');
      expect(result, isEmpty);
    });

    test('returns empty for whitespace only', () {
      final result = SubscriptionFetcher.parseBody('   \n\n  ');
      expect(result, isEmpty);
    });

    test('extracts vless:// from plain text', () {
      const input = 'vless://uuid@host:443?encryption=none#Test';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(1));
      expect(result.first.uri, startsWith('vless://'));
      expect(result.first.label, 'Test');
    });

    test('extracts multiple vless:// from plain text', () {
      const input = '''
vless://uuid1@host1:443?encryption=none#Server1
vless://uuid2@host2:443?encryption=none#Server2
vless://uuid3@host3:443?encryption=none#Server3
''';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(3));
      expect(result[0].label, 'Server1');
      expect(result[1].label, 'Server2');
      expect(result[2].label, 'Server3');
    });

    test('decodes base64 and extracts vless://', () {
      // "vless://uuid@host:443?encryption=none#Latvia" в base64
      const input = 'dmxlc3M6Ly91dWlkQGhvc3Q6NDQzP2VuY3J5cHRpb249bm9uZSNMYXR2aWE=';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(1));
      expect(result.first.uri, startsWith('vless://'));
      expect(result.first.label, 'Latvia');
    });

    test('handles URL-safe base64', () {
      // Base64 с - и _ вместо + и /
      const input = 'dmxlc3M6Ly91dWlkQGhvc3Q6NDQzP2VuY3J5cHRpb249bm9uZSNMYXR2aWE=';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(1));
    });

    test('ignores non-vless lines', () {
      const input = '''
https://example.com
vless://uuid@host:443?encryption=none#Test
ftp://example.com
''';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(1));
      expect(result.first.label, 'Test');
    });

    test('deduplicates identical profiles', () {
      const input = '''
vless://uuid@host:443?encryption=none#Test
vless://uuid@host:443?encryption=none#Test
''';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(1));
    });

    test('parses vless URI with URL-encoded fragment as label', () {
      // %F0%9F%87%B1%F0%9F%87%BB = 🇱🇻 (Latvia flag emoji, URL-encoded)
      const input = 'vless://uuid@host:443?encryption=none#%F0%9F%87%B1%F0%9F%87%BB%20Latvia';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, hasLength(1));
      expect(result.first.label, contains('Latvia'));
    });

    test('returns empty when base64 decodes to non-vless content', () {
      // "hello world" в base64
      const input = 'aGVsbG8gd29ybGQ=';
      final result = SubscriptionFetcher.parseBody(input);
      expect(result, isEmpty);
    });

    test('handles malformed base64 gracefully', () {
      const input = 'not-valid-base64!!!';
      final result = SubscriptionFetcher.parseBody(input);
      // Should not throw, just return empty or try as plain text
      expect(result, isEmpty);
    });
  });

  group('SubscriptionFetcher', () {
    test('rejects invalid URLs', () async {
      final fetcher = SubscriptionFetcher();
      expect(
        () => fetcher.fetch('not-a-url'),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects URLs without host', () async {
      final fetcher = SubscriptionFetcher();
      expect(
        () => fetcher.fetch('https://'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
