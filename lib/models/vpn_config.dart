/// Tunnel protocols supported by the client.
enum VpnProtocol {
  wireguard('WireGuard'),
  openvpn('OpenVPN'),
  ikev2('IKEv2');

  const VpnProtocol(this.label);

  final String label;
}

/// DNS resolution modes.
enum DnsPreference {
  automatic('Automatic'),
  adBlocking('Ad-blocking'),
  custom('Custom');

  const DnsPreference(this.label);

  final String label;
}

/// Immutable tunnel configuration passed to [TunnelManager].
class VpnConfig {
  const VpnConfig({
    this.protocol = VpnProtocol.wireguard,
    this.dns = DnsPreference.automatic,
    this.killSwitch = false,
    this.customDns = '1.1.1.1',
  });

  final VpnProtocol protocol;
  final DnsPreference dns;
  final bool killSwitch;
  final String customDns;

  VpnConfig copyWith({
    VpnProtocol? protocol,
    DnsPreference? dns,
    bool? killSwitch,
    String? customDns,
  }) {
    return VpnConfig(
      protocol: protocol ?? this.protocol,
      dns: dns ?? this.dns,
      killSwitch: killSwitch ?? this.killSwitch,
      customDns: customDns ?? this.customDns,
    );
  }
}
