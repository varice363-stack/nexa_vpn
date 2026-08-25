/// What the user pasted into the "I have a key" field.
enum KeyInputKind {
  /// A Nexa redemption code: NEXA-XXXX-XXXX. Resolved via the backend.
  nexaCode,

  /// A third-party `vless://` share link. Used locally, never sent to us.
  vlessUri,

  /// An `https://` subscription URL that resolves to one or more profiles.
  ///
  /// This is what most providers actually hand their customers, so refusing
  /// it would turn away the very users the app is meant to win over.
  subscriptionUrl,

  /// Unrecognisable input.
  unknown,
}

/// Result of classifying user input on the key screen.
///
/// The product sells its own keys but must also accept keys from any other
/// provider — that is the Hiddify-style flow the app is modelled on.
class KeyInput {
  const KeyInput._(this.kind, this.value, {this.label});

  final KeyInputKind kind;

  /// Normalised value: canonical code, or the trimmed URI.
  final String value;

  /// Human-readable name parsed from a `vless://` fragment, if any.
  final String? label;

  bool get isValid => kind != KeyInputKind.unknown;

  static const _codeBody = 8;

  /// Classifies raw input from the text field.
  ///
  /// Deliberately forgiving: people paste with stray whitespace, in the
  /// wrong case, or with the `NEXA-` prefix missing.
  factory KeyInput.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const KeyInput._(KeyInputKind.unknown, '');

    final lower = trimmed.toLowerCase();

    // Subscription link: fetched later, so only the shape is checked here.
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) {
        return KeyInput._(KeyInputKind.unknown, trimmed);
      }
      final label = uri.fragment.isEmpty
          ? null
          : Uri.decodeComponent(uri.fragment);
      return KeyInput._(KeyInputKind.subscriptionUrl, trimmed, label: label);
    }

    if (lower.startsWith('vless://')) {
      final uri = Uri.tryParse(trimmed);
      // A usable VLESS link needs at least a UUID and a host:port.
      if (uri == null ||
          uri.userInfo.isEmpty ||
          uri.host.isEmpty ||
          (uri.port == 0)) {
        return KeyInput._(KeyInputKind.unknown, trimmed);
      }
      final label = uri.fragment.isEmpty
          ? null
          : Uri.decodeComponent(uri.fragment);
      return KeyInput._(KeyInputKind.vlessUri, trimmed, label: label);
    }

    // Other proxy schemes are recognised only to give a precise error —
    // the tunnel engine speaks VLESS.
    for (final scheme in ['vmess://', 'trojan://', 'ss://', 'socks://']) {
      if (lower.startsWith(scheme)) {
        return KeyInput._(KeyInputKind.unknown, trimmed);
      }
    }

    final code = _normaliseCode(trimmed);
    if (code.isNotEmpty) return KeyInput._(KeyInputKind.nexaCode, code);

    return KeyInput._(KeyInputKind.unknown, trimmed);
  }

  /// Mirrors the backend's `normaliseAccessCode` so the UI can validate
  /// before spending a round-trip.
  static String _normaliseCode(String input) {
    final cleaned =
        input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final body =
        cleaned.startsWith('NEXA') ? cleaned.substring(4) : cleaned;
    if (body.length != _codeBody) return '';
    return 'NEXA-${body.substring(0, 4)}-${body.substring(4)}';
  }
}
