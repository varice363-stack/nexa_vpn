import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/services/vpn/xray_protocol_enhancer.dart';

void main() {
  group('XrayProtocolEnhancer', () {
    const enhancer = XrayProtocolEnhancer();

    // Sample VLESS config without anti-censorship features
    const plainConfig = '''
{
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "example.com",
            "port": 443,
            "users": [
              {
                "id": "test-uuid",
                "encryption": "none",
                "flow": ""
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "example.com"
        }
      }
    }
  ]
}
''';

    test('enhance adds Reality settings', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: true,
        enableVision: false,
        enableXhttp: false,
        enableChromeFp: false,
        enableEmptySni: false,
      );

      final decoded = jsonDecode(enhanced) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List;
      final outbound = outbounds[0] as Map<String, dynamic>;
      final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;

      expect(streamSettings['security'], 'reality');
      expect(streamSettings['realitySettings'], isNotNull);

      final realitySettings =
          streamSettings['realitySettings'] as Map<String, dynamic>;
      expect(realitySettings['serverName'], 'icloud.com');
      expect(realitySettings['fingerprint'], 'chrome');
    });

    test('enhance adds Vision encryption', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: false,
        enableVision: true,
        enableXhttp: false,
        enableChromeFp: false,
        enableEmptySni: false,
      );

      final decoded = jsonDecode(enhanced) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List;
      final outbound = outbounds[0] as Map<String, dynamic>;
      final settings = outbound['settings'] as Map<String, dynamic>;
      final vnext = settings['vnext'] as List;
      final server = vnext[0] as Map<String, dynamic>;
      final users = server['users'] as List;
      final user = users[0] as Map<String, dynamic>;

      expect(user['encryption'], 'vision');
      expect(user['flow'], 'xtls-rprx-vision');
    });

    test('enhance adds XHTTP transport', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: false,
        enableVision: false,
        enableXhttp: true,
        enableChromeFp: false,
        enableEmptySni: false,
      );

      final decoded = jsonDecode(enhanced) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List;
      final outbound = outbounds[0] as Map<String, dynamic>;
      final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;

      expect(streamSettings['network'], 'xhttp');
      expect(streamSettings['xhttpSettings'], isNotNull);

      final xhttpSettings =
          streamSettings['xhttpSettings'] as Map<String, dynamic>;
      expect(xhttpSettings['maxConcurrentUploads'], 1);
    });

    test('enhance sets empty SNI', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: false,
        enableVision: false,
        enableXhttp: false,
        enableChromeFp: false,
        enableEmptySni: true,
      );

      final decoded = jsonDecode(enhanced) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List;
      final outbound = outbounds[0] as Map<String, dynamic>;
      final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;
      final tlsSettings = streamSettings['tlsSettings'] as Map<String, dynamic>;

      expect(tlsSettings['serverName'], '');
    });

    test('enhance applies all anti-censorship features', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: true,
        enableVision: true,
        enableXhttp: true,
        enableChromeFp: true,
        enableEmptySni: true,
      );

      final decoded = jsonDecode(enhanced) as Map<String, dynamic>;
      final outbounds = decoded['outbounds'] as List;
      final outbound = outbounds[0] as Map<String, dynamic>;

      // Check Reality
      final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;
      expect(streamSettings['security'], 'reality');
      expect(streamSettings['realitySettings'], isNotNull);

      // Check Vision
      final settings = outbound['settings'] as Map<String, dynamic>;
      final vnext = settings['vnext'] as List;
      final server = vnext[0] as Map<String, dynamic>;
      final users = server['users'] as List;
      final user = users[0] as Map<String, dynamic>;
      expect(user['encryption'], 'vision');
      expect(user['flow'], 'xtls-rprx-vision');

      // Check XHTTP
      expect(streamSettings['network'], 'xhttp');
      expect(streamSettings['xhttpSettings'], isNotNull);
    });

    test('enhance returns unchanged config on invalid JSON', () {
      const invalidConfig = 'not a json';
      final enhanced = enhancer.enhance(invalidConfig);
      expect(enhanced, invalidConfig);
    });

    test('hasReality detects Reality in config', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: true,
        enableVision: false,
        enableXhttp: false,
        enableChromeFp: false,
        enableEmptySni: false,
      );

      expect(XrayProtocolEnhancer.hasReality(enhanced), true);
      expect(XrayProtocolEnhancer.hasReality(plainConfig), false);
    });

    test('hasVision detects Vision in config', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: false,
        enableVision: true,
        enableXhttp: false,
        enableChromeFp: false,
        enableEmptySni: false,
      );

      expect(XrayProtocolEnhancer.hasVision(enhanced), true);
      expect(XrayProtocolEnhancer.hasVision(plainConfig), false);
    });

    test('hasXhttp detects XHTTP in config', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: false,
        enableVision: false,
        enableXhttp: true,
        enableChromeFp: false,
        enableEmptySni: false,
      );

      expect(XrayProtocolEnhancer.hasXhttp(enhanced), true);
      expect(XrayProtocolEnhancer.hasXhttp(plainConfig), false);
    });

    test('describeProtection returns correct description', () {
      final enhanced = enhancer.enhance(
        plainConfig,
        enableReality: true,
        enableVision: true,
        enableXhttp: true,
        enableChromeFp: true,
        enableEmptySni: true,
      );

      final description = XrayProtocolEnhancer.describeProtection(enhanced);
      expect(description, contains('Reality'));
      expect(description, contains('Vision'));
      expect(description, contains('XHTTP'));
      expect(description, contains('Protected'));

      final plainDescription =
          XrayProtocolEnhancer.describeProtection(plainConfig);
      expect(plainDescription, contains('Plain VLESS'));
      expect(plainDescription, contains('no anti-censorship'));
    });
  });
}
