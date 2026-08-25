import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nexa_vpn/services/vpn/xray_config_hardener.dart';

/// Regression guard for the vulnerability that affects every known VLESS
/// client: the local SOCKS5 inbound runs with `auth: noauth`, so any app on
/// the device can reach `127.0.0.1:10807`, bypass VpnService, and read the
/// proxy's real outbound IP. Per-app split tunneling and Android Private
/// Space do not protect against it.
///
/// The fixture below is the exact shape `flutter_vless` generates
/// (`lib/url/xray_config_model.dart`, `XrayInbound.localSocksTunnel`).

const _vulnerableConfig = '''
{
  "inbounds": [
    {
      "tag": "in_proxy",
      "listen": "127.0.0.1",
      "port": 10807,
      "protocol": "socks",
      "settings": {"auth": "noauth", "udp": true, "userLevel": 8}
    }
  ],
  "outbounds": [
    {"tag": "proxy", "protocol": "vless", "settings": {}}
  ]
}
''';

const _hardener = XrayConfigHardener();

Map<String, dynamic> _socksSettings(String config) {
  final decoded = jsonDecode(config) as Map<String, dynamic>;
  final inbound = (decoded['inbounds'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((i) => i['protocol'] == 'socks');
  return (inbound['settings'] as Map).cast<String, dynamic>();
}

void main() {
  group('detection — the plugin ships the vulnerable inbound', () {
    test('flags the config flutter_vless generates', () {
      // If this ever fails, the plugin fixed it upstream and the workaround
      // can be reconsidered.
      expect(XrayConfigHardener.isVulnerable(_vulnerableConfig), isTrue);
    });

    test('flags a password-protected inbound that still allows UDP', () {
      // SOCKS5 UDP associate is not covered by auth, so this is still open.
      const config = '''
      {"inbounds":[{"protocol":"socks","port":10807,
        "settings":{"auth":"password","accounts":[{"user":"a","pass":"b"}],
        "udp":true}}],"outbounds":[]}
      ''';
      expect(XrayConfigHardener.isVulnerable(config), isTrue);
    });

    test('flags an empty accounts list', () {
      const config = '''
      {"inbounds":[{"protocol":"socks","port":10807,
        "settings":{"auth":"password","accounts":[],"udp":false}}],
        "outbounds":[]}
      ''';
      expect(XrayConfigHardener.isVulnerable(config), isTrue);
    });

    test('does not flag a properly locked inbound', () {
      const config = '''
      {"inbounds":[{"protocol":"socks","port":10807,
        "settings":{"auth":"password","accounts":[{"user":"a","pass":"b"}],
        "udp":false}}],"outbounds":[]}
      ''';
      expect(XrayConfigHardener.isVulnerable(config), isFalse);
    });
  });

  group('hardening — the hole is actually closed', () {
    test('requires a password on the local SOCKS inbound', () {
      final hardened = _hardener.harden(
        _vulnerableConfig,
        username: 'nexa',
        password: 'secret123',
      );

      final settings = _socksSettings(hardened);
      expect(settings['auth'], 'password');
      expect(settings['accounts'], [
        {'user': 'nexa', 'pass': 'secret123'},
      ]);
    });

    test('disables SOCKS UDP, which auth cannot cover', () {
      final hardened = _hardener.harden(
        _vulnerableConfig,
        username: 'nexa',
        password: 'secret123',
      );

      expect(_socksSettings(hardened)['udp'], isFalse);
    });

    test('the hardened config no longer reports as vulnerable', () {
      final hardened = _hardener.harden(
        _vulnerableConfig,
        username: 'nexa',
        password: 'secret123',
      );

      expect(XrayConfigHardener.isVulnerable(_vulnerableConfig), isTrue);
      expect(XrayConfigHardener.isVulnerable(hardened), isFalse);
    });
  });

  group('compatibility — the plugin must still accept the config', () {
    test('keeps protocol and port, which the validator checks', () {
      final hardened = _hardener.harden(
        _vulnerableConfig,
        username: 'nexa',
        password: 'secret123',
      );

      final decoded = jsonDecode(hardened) as Map<String, dynamic>;
      final inbound =
          (decoded['inbounds'] as List).cast<Map<String, dynamic>>().single;

      // flutter_vless' XrayConfigValidator requires a protocol string and a
      // valid port on every inbound; breaking either would throw at startup.
      expect(inbound['protocol'], 'socks');
      expect(inbound['port'], 10807);
      expect(inbound['listen'], '127.0.0.1');
    });

    test('leaves outbounds untouched — that is the actual tunnel', () {
      final hardened = _hardener.harden(
        _vulnerableConfig,
        username: 'nexa',
        password: 'secret123',
      );

      final before = (jsonDecode(_vulnerableConfig)
          as Map<String, dynamic>)['outbounds'];
      final after =
          (jsonDecode(hardened) as Map<String, dynamic>)['outbounds'];
      expect(after, before);
    });

    test('preserves unrelated inbound settings', () {
      final hardened = _hardener.harden(
        _vulnerableConfig,
        username: 'nexa',
        password: 'secret123',
      );

      expect(_socksSettings(hardened)['userLevel'], 8);
    });

    test('ignores non-SOCKS inbounds', () {
      const config = '''
      {"inbounds":[{"protocol":"dokodemo-door","port":10808,
        "settings":{"network":"tcp"}}],"outbounds":[]}
      ''';
      final hardened = _hardener.harden(
        config,
        username: 'nexa',
        password: 'secret',
      );

      final inbound = (jsonDecode(hardened) as Map<String, dynamic>)['inbounds']
          as List;
      expect((inbound.single as Map)['settings'], {'network': 'tcp'});
    });
  });

  group('robustness — never break a working connection', () {
    test('passes malformed JSON through untouched', () {
      const broken = 'not json at all';
      expect(_hardener.harden(broken, username: 'a', password: 'b'), broken);
    });

    test('passes a config with no inbounds through untouched', () {
      const config = '{"outbounds":[]}';
      expect(_hardener.harden(config, username: 'a', password: 'b'), config);
    });

    test('creates settings when the inbound has none', () {
      const config =
          '{"inbounds":[{"protocol":"socks","port":10807}],"outbounds":[]}';
      final hardened =
          _hardener.harden(config, username: 'nexa', password: 'pw');

      expect(_socksSettings(hardened)['auth'], 'password');
      expect(XrayConfigHardener.isVulnerable(hardened), isFalse);
    });
  });

  group('secret generation', () {
    test('is long enough to resist guessing', () {
      expect(XrayConfigHardener.generateSecret().length, 32);
    });

    test('differs every call — a leaked secret dies with the session', () {
      final secrets = List.generate(50, (_) =>
          XrayConfigHardener.generateSecret());
      expect(secrets.toSet().length, 50);
    });

    test('stays alphanumeric so it survives JSON and logs', () {
      final secret = XrayConfigHardener.generateSecret(200);
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(secret), isTrue);
    });
  });
}
