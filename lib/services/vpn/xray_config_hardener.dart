import 'dart:convert';
import 'dart:math';

/// Closes the local SOCKS5 hole that every known VLESS client shares.
///
/// Background: clients built on xray/sing-box start a local SOCKS5 proxy with
/// `auth: noauth`. Any app on the device — including a state-mandated spyware
/// module — can connect to `127.0.0.1:10807` directly, bypass `VpnService`
/// entirely, and read the real outbound IP of the proxy server. Per-app split
/// tunneling does not help, and Android Private Space does not help either,
/// because loopback is not isolated there.
///
/// Disclosed 2026-03-10 to every major client (Hiddify, v2rayNG, v2RayTun,
/// V2BOX, Happ, Exclave, Npv Tunnel, Neko Box); none had shipped a fix a month
/// later. The plugin we depend on generates the same insecure inbound
/// (`flutter_vless/lib/url/xray_config_model.dart`, `localSocksTunnel`).
///
/// We cannot patch the plugin, but `startVless()` takes a JSON string and the
/// plugin's validator only requires `protocol` and a valid `port` on each
/// inbound — so the config can be hardened in transit.
class XrayConfigHardener {
  const XrayConfigHardener();

  /// Alphabet without look-alike characters; the secret is never shown to a
  /// human, but keeping it URL-safe avoids surprises if it is ever logged.
  static const _alphabet =
      'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a fresh credential. A new one per tunnel start means a leaked
  /// secret is worthless the moment the session ends.
  static String generateSecret([int length = 32]) {
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }

  /// Rewrites [rawConfig] so every local SOCKS inbound demands a password.
  ///
  /// Returns the config unchanged when it cannot be parsed — failing closed
  /// here would break connections for a defence-in-depth measure, and the
  /// plugin validates the JSON immediately afterwards anyway.
  ///
  /// [username] and [password] must match what the tunnel itself uses; the
  /// native side dials this inbound through tun2socks, so credentials are
  /// injected into the config it reads.
  String harden(
    String rawConfig, {
    required String username,
    required String password,
    bool disableUdp = true,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawConfig);
    } on FormatException {
      return rawConfig;
    }
    if (decoded is! Map<String, dynamic>) return rawConfig;

    final inbounds = decoded['inbounds'];
    if (inbounds is! List) return rawConfig;

    for (final inbound in inbounds) {
      if (inbound is! Map<String, dynamic>) continue;
      if (inbound['protocol'] != 'socks') continue;

      final settings = inbound['settings'];
      final map = settings is Map
          ? settings.cast<String, dynamic>()
          : <String, dynamic>{};

      map['auth'] = 'password';
      map['accounts'] = [
        {'user': username, 'pass': password},
      ];

      // SOCKS5 UDP associate is not covered by username/password auth, so a
      // local attacker could still reach the proxy over UDP. Turning it off is
      // the only way to make the credential meaningful. Cost: QUIC/HTTP3 falls
      // back to TCP.
      if (disableUdp) map['udp'] = false;

      inbound['settings'] = map;
    }

    return jsonEncode(decoded);
  }

  /// Reports whether a config still exposes an unauthenticated SOCKS inbound.
  ///
  /// Used by the in-app security check so the claim can be verified rather
  /// than taken on trust.
  static bool isVulnerable(String rawConfig) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawConfig);
    } on FormatException {
      return false;
    }
    if (decoded is! Map<String, dynamic>) return false;

    final inbounds = decoded['inbounds'];
    if (inbounds is! List) return false;

    for (final inbound in inbounds) {
      if (inbound is! Map) continue;
      if (inbound['protocol'] != 'socks') continue;

      final settings = inbound['settings'];
      if (settings is! Map) return true;

      final auth = settings['auth'];
      if (auth != 'password') return true;

      final accounts = settings['accounts'];
      if (accounts is! List || accounts.isEmpty) return true;

      // A password-protected TCP path plus open UDP is still reachable.
      if (settings['udp'] == true) return true;
    }
    return false;
  }
}
