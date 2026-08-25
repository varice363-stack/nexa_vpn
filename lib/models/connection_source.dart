import 'access_key.dart';

/// Where a connection came from.
///
/// The product sells its own keys but must work just as well with a key the
/// user already owns — that is the whole point of the app being usable on
/// day one. Both origins are first-class: nothing downstream of
/// [ConnectionSource] is allowed to care which one it is holding.
enum ConnectionOrigin {
  /// Issued by us (redeemed code or purchased subscription).
  nexa,

  /// A `vless://` link the user pasted in, belonging to another provider.
  /// Stored on the device only.
  imported,
}

/// A single thing the user can connect to.
///
/// This is the one type the tunnel layer is meant to consume. It flattens
/// the two very different sources — backend [AccessKey]s and locally
/// imported links — into the only shape that matters for connecting:
/// a label to show, and a VLESS URI to dial.
class ConnectionSource {
  const ConnectionSource({
    required this.id,
    required this.label,
    required this.uri,
    required this.origin,
    this.expiresAt,
    this.isExpired = false,
  });

  /// Stable identity, unique across both origins.
  ///
  /// Nexa keys use `nexa:<keyId>`; imported links use `imported:<uri>` —
  /// the URI itself, because that is what makes an imported key unique
  /// (re-importing the same link must not create a second entry).
  final String id;

  /// Name shown in the UI.
  final String label;

  /// The `vless://...` link handed to the tunnel engine.
  final String uri;

  final ConnectionOrigin origin;

  /// Known only for Nexa keys; imported links carry no expiry we can trust.
  final DateTime? expiresAt;

  /// Server-side status for Nexa keys (revoked / expired).
  final bool isExpired;

  bool get isNexa => origin == ConnectionOrigin.nexa;
  bool get isImported => origin == ConnectionOrigin.imported;

  /// Host of the endpoint, used to tell two entries apart in lists.
  String get host => Uri.tryParse(uri)?.host ?? '—';

  /// Whether this source can actually be dialled right now.
  bool get isUsable => !isExpired && uri.startsWith('vless://');

  /// Builds a source from a Nexa access key.
  ///
  /// Returns null when the key has no config yet: a key without a
  /// `configUri` cannot be connected to, and offering it would produce a
  /// dead button.
  static ConnectionSource? fromAccessKey(AccessKey key) {
    final uri = key.configUri;
    if (uri == null || uri.isEmpty) return null;
    return ConnectionSource(
      id: 'nexa:${key.id}',
      label: key.name,
      uri: uri,
      origin: ConnectionOrigin.nexa,
      expiresAt: key.expiresAt,
      isExpired: !key.isActive,
    );
  }

  /// Builds a source from a locally imported `vless://` link.
  static ConnectionSource fromImported({
    required String uri,
    required String label,
  }) {
    return ConnectionSource(
      id: 'imported:$uri',
      label: label,
      uri: uri,
      origin: ConnectionOrigin.imported,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectionSource && other.id == id && other.uri == uri;

  @override
  int get hashCode => Object.hash(id, uri);

  @override
  String toString() => 'ConnectionSource($id, $label)';
}
