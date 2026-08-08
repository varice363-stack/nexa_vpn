import 'vpn_config.dart';

/// User-editable application settings, persisted via [ConfigRepository].
class AppSettings {
  const AppSettings({
    this.protocol = VpnProtocol.wireguard,
    this.dns = DnsPreference.automatic,
    this.killSwitch = false,
    this.autoConnect = false,
    this.notificationsEnabled = true,
  });

  final VpnProtocol protocol;
  final DnsPreference dns;
  final bool killSwitch;
  final bool autoConnect;
  final bool notificationsEnabled;

  /// The tunnel-facing subset of the settings.
  VpnConfig get vpnConfig => VpnConfig(
        protocol: protocol,
        dns: dns,
        killSwitch: killSwitch,
      );

  AppSettings copyWith({
    VpnProtocol? protocol,
    DnsPreference? dns,
    bool? killSwitch,
    bool? autoConnect,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      protocol: protocol ?? this.protocol,
      dns: dns ?? this.dns,
      killSwitch: killSwitch ?? this.killSwitch,
      autoConnect: autoConnect ?? this.autoConnect,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
