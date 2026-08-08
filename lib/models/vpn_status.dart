/// Tunnel handshake phases.
enum TunnelPhase {
  idle,
  handshake,
  authenticating,
  establishing,
  connected,
  disconnecting,
  error;

  String get label => switch (this) {
        idle => 'Idle',
        handshake => 'Handshake',
        authenticating => 'Authenticating',
        establishing => 'Establishing tunnel',
        connected => 'Connected',
        disconnecting => 'Disconnecting',
        error => 'Error',
      };
}

/// High-level connection status exposed to the UI.
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  String get label => switch (this) {
        disconnected => 'Not connected',
        connecting => 'Connecting…',
        connected => 'Connected',
        disconnecting => 'Disconnecting…',
        error => 'Connection error',
      };
}
