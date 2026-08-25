import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Key under which the VpnService disclosure acceptance is persisted.
const _consentKey = 'nexa_vpn_consent_accepted';

/// Whether the user has accepted the prominent VpnService disclosure.
///
/// Google Play requires an in-app disclosure — separate from the privacy
/// policy — explaining what the app does with user traffic, accepted by an
/// affirmative action. Until that happens the app must not open a tunnel.
final vpnConsentProvider =
    NotifierProvider<VpnConsentNotifier, bool>(VpnConsentNotifier.new);

class VpnConsentNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_consentKey) ?? false;
  }

  Future<void> accept() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_consentKey, true);
  }

  /// Clears the acceptance — used when the user revokes consent.
  Future<void> revoke() async {
    state = false;
    await ref.read(sharedPreferencesProvider).remove(_consentKey);
  }
}
