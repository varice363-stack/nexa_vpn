// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nexa VPN';

  @override
  String get appTagline => 'Private • Secure • Fast';

  @override
  String get navHome => 'Home';

  @override
  String get navServers => 'Servers';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonShare => 'Share';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonName => 'Name';

  @override
  String get commonSignIn => 'Sign in';

  @override
  String get commonCreateAccount => 'Create account';

  @override
  String get errorNetwork =>
      'No connection to the server. Please check your network.';

  @override
  String get errorUnexpected => 'Unexpected error. Please try again.';

  @override
  String get onboardingTitle1 => 'One-tap protection';

  @override
  String get onboardingBody1 =>
      'Connect with a single tap. Nexa VPN works silently in the background and keeps your session alive.';

  @override
  String get onboardingTitle2 => 'Military-grade encryption';

  @override
  String get onboardingBody2 =>
      'Your traffic is protected with the modern VLESS protocol over Xray REALITY.';

  @override
  String get onboardingTitle3 => 'Blazing fast speeds';

  @override
  String get onboardingBody3 =>
      'A strict no-logs policy keeps your activity private — always.';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get homeGreeting => 'Your connection is protected';

  @override
  String get homeNotificationsSoon => 'Notifications are coming soon';

  @override
  String get powerTapToConnect => 'Tap to connect';

  @override
  String get powerTapToDisconnect => 'Tap to disconnect';

  @override
  String get powerConnecting => 'Connecting…';

  @override
  String get powerDisconnecting => 'Disconnecting…';

  @override
  String get powerNotConnected => 'Not connected';

  @override
  String get powerConnectionError => 'Connection error';

  @override
  String powerConnectedFor(String duration) {
    return 'Connected • $duration';
  }

  @override
  String get statsDownload => 'Download';

  @override
  String get statsUpload => 'Upload';

  @override
  String get statsPing => 'Ping';

  @override
  String get accessActive => 'Access active';

  @override
  String get accessChecking => 'Checking access…';

  @override
  String get accessNoKeyYet => 'No access key yet';

  @override
  String get accessNoActiveKey => 'No active key';

  @override
  String get accessGenerateHint => 'Generate a key to use Nexa on any device';

  @override
  String get accessGetAccess => 'Get access';

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to manage your devices and keys';

  @override
  String get loginEnterEmail => 'Enter your email';

  @override
  String get loginEnterPassword => 'Enter your password';

  @override
  String get loginInvalidEmail => 'Enter a valid email address';

  @override
  String get loginBadCredentials => 'Invalid email or password.';

  @override
  String get loginBlocked => 'This account is blocked. Contact support.';

  @override
  String get loginContinueAsGuest => 'Continue as guest';

  @override
  String get registerSubtitle => 'One account for all your devices';

  @override
  String get registerEnterName => 'Enter your name';

  @override
  String get registerEnterPassword => 'Enter a password';

  @override
  String get registerConfirmPassword => 'Confirm password';

  @override
  String get registerConfirmHint => 'Confirm your password';

  @override
  String get registerPasswordsMismatch => 'Passwords do not match';

  @override
  String get registerMinChars => 'At least 8 characters';

  @override
  String get registerMaxChars => 'At most 72 characters';

  @override
  String get registerNeedDigit => 'Add at least one digit';

  @override
  String get registerNeedLetter => 'Add at least one letter';

  @override
  String get registerAlreadyHaveAccount => 'Already have an account?';

  @override
  String get registerEmailTaken =>
      'This email is already registered. Try signing in.';

  @override
  String get registerInvalidInput =>
      'Invalid input. Check the form and try again.';

  @override
  String get serversFilterAll => 'All';

  @override
  String get serversFilterFastest => 'Fastest';

  @override
  String get serversFilterPremium => 'Premium';

  @override
  String get serversFilterSaved => 'Saved';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmptyTitle => 'All caught up';

  @override
  String get notificationsEmptyBody =>
      'Connection events and offers will appear here.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Tunnel and privacy preferences';

  @override
  String get settingsSectionConnection => 'CONNECTION';

  @override
  String get settingsSectionPrivacy => 'PRIVACY & SECURITY';

  @override
  String get settingsSectionBehavior => 'BEHAVIOR';

  @override
  String get settingsSectionData => 'DATA';

  @override
  String get settingsSectionApp => 'APP';

  @override
  String get settingsAutoConnect => 'Auto-connect';

  @override
  String get settingsAutoConnectHint =>
      'Connect to the fastest server on app launch';

  @override
  String get settingsProtocol => 'Protocol';

  @override
  String get settingsProtocolHint => 'Tunnel transport protocol';

  @override
  String get settingsKillSwitch => 'Kill switch';

  @override
  String get settingsKillSwitchHint => 'Block all traffic if the tunnel drops';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsDnsHint => 'DNS resolution mode';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsHint => 'Connection events and app alerts';

  @override
  String get settingsClearLogs => 'Clear diagnostic logs';

  @override
  String get settingsClearLogsHint => 'Erase the in-app event buffer';

  @override
  String get settingsLogsCleared => 'Logs cleared';

  @override
  String get settingsAbout => 'About Nexa VPN';

  @override
  String get settingsAboutHint => 'Version, privacy policy, changelog';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'Interface language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get commonEdit => 'Edit profile';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonUpgrade => 'Upgrade';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonPremium => 'Premium';

  @override
  String get commonFreePlan => 'Free plan';

  @override
  String get commonDevices => 'Devices';

  @override
  String get commonProtocol => 'Protocol';

  @override
  String get commonServer => 'Server';

  @override
  String get commonAddress => 'Address';

  @override
  String get commonExpires => 'Expires';

  @override
  String get bannerCarousel => 'Recommended';

  @override
  String bannerDuration(int seconds) => '${seconds}s';

  @override
  String get bannerTapToOpen => 'Tap to open';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGuest => 'Guest';

  @override
  String get profileGuestMode => 'Guest mode';

  @override
  String get profileGuestHint =>
      'Sign in to sync devices, keys and subscriptions';

  @override
  String get profilePremiumMember => 'Premium member';

  @override
  String get profileAllUnlocked => 'All features unlocked';

  @override
  String get profileUpgradeHint =>
      'Upgrade for unlimited data and 4K streaming';

  @override
  String get profileNexaPremium => 'Nexa Premium';

  @override
  String get profileMyAccess => 'My Access';

  @override
  String get profileMyAccessHint => 'Subscription and access keys';

  @override
  String get profileSessions => 'Sessions';

  @override
  String get profilePaymentHistory => 'Payment History';

  @override
  String get profilePaymentHistoryHint => 'Checkouts and payments';

  @override
  String get profileSettingsHint => 'Protocol, kill switch, DNS';

  @override
  String get profileNotificationsHint => 'App events and alerts';

  @override
  String get profileSupport => 'Support';

  @override
  String get profileSupportHint => 'Contact us or read the FAQ';

  @override
  String get profileAbout => 'About';

  @override
  String get profileAboutHint => 'Version and legal';

  @override
  String get profileMyActivity => 'MY ACTIVITY';

  @override
  String get profileAccount => 'ACCOUNT';

  @override
  String get profileOnline => 'Online';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileMyCode => 'My code';

  @override
  String get profileSignedOut => 'Signed out. Welcome back anytime.';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileChangePasswordHint => 'Update your account password';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profilePasswordChanged => 'Password updated';

  @override
  String get accessTitle => 'My Access';

  @override
  String get accessLoading => 'Loading your access…';

  @override
  String get accessKeys => 'Keys';

  @override
  String get accessPremiumAccess => 'Premium access';

  @override
  String get accessPremiumActive => 'Premium active';

  @override
  String get accessNoActivePlan => 'No active plan';

  @override
  String get accessNoKeys => 'No access keys yet';

  @override
  String get accessSubscribeHint => 'Subscribe to generate access keys';

  @override
  String get accessGetAccessHint => 'Get access to generate your personal key';

  @override
  String get accessExpired =>
      'Your subscription has expired — renew to keep access.';

  @override
  String get accessOfflineHint =>
      'Cannot reach the server. Your access data will appear once the connection is restored.';

  @override
  String get vlessActiveConfig => 'Active VLESS configuration';

  @override
  String get vlessCopy => 'Copy VLESS';

  @override
  String get vlessShowQr => 'Show QR';

  @override
  String get vlessScanHint => 'Scan with any VLESS client';

  @override
  String get vlessUnavailable => 'Configuration unavailable';

  @override
  String get vlessNotReady =>
      'The assigned server is not ready yet. Please check back shortly.';

  @override
  String get vlessCompatible =>
      'Works with v2rayNG, Shadowrocket, sing-box and other clients.';

  @override
  String get vlessCopied => 'VLESS configuration copied';

  @override
  String get vlessNeverExpires => 'Never (lifetime)';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumLoadingPlans => 'Loading plans…';

  @override
  String get premiumNoPlans => 'No plans available';

  @override
  String get premiumNoPlansHint =>
      'Check back soon — plans are being prepared.';

  @override
  String get premiumOfflineHint =>
      'Cannot reach the server. Plans will appear once the connection is restored.';

  @override
  String get premiumActive => 'Premium active';

  @override
  String get premiumSignInToSubscribe => 'Sign in to subscribe';

  @override
  String get premiumOpenPaymentPage => 'Open payment page';

  @override
  String get premiumPaymentTitle => 'Payment';

  @override
  String get premiumPaymentFailed => 'Payment failed';

  @override
  String get premiumPaymentSuccess => 'Payment successful — access activated';

  @override
  String get premiumSecurePaymentNote =>
      'Payment is processed by a secure provider. Cancel anytime.';

  @override
  String get premiumPaymentsComingSoonNote =>
      'Prices are final. In-app payment is being connected.';

  @override
  String get premiumPaymentsComingSoonTitle => 'Payment is coming soon';

  @override
  String get premiumPaymentsComingSoonBody =>
      'In-app purchase is not connected yet, so we are not taking payments. Prices above are final. If you already have an access code, activate it now.';

  @override
  String get premiumIHaveCode => 'I have an access code';

  @override
  String get premiumCheckPaymentStatus => 'I have paid — check status';

  @override
  String premiumGetFor(String price) {
    return 'Get Premium — $price';
  }

  @override
  String premiumPerMonth(String price) {
    return '≈$price/mo';
  }

  @override
  String premiumSavings(String amount) {
    return 'Save $amount';
  }

  @override
  String premiumDaysOfAccess(int days) {
    return '$days days of access';
  }

  @override
  String get premiumTrialHint =>
      'Full access, no card required. One trial per account.';

  @override
  String get serversTitle => 'Servers';

  @override
  String get serversLoading => 'Loading locations…';

  @override
  String get serversFetching => 'Fetching servers…';

  @override
  String get serversCurrent => 'Current server';

  @override
  String get serversNotFound => 'No servers found';

  @override
  String get serversResetFilters => 'Reset filters';

  @override
  String get serversTryDifferent =>
      'Try a different query or reset the filters';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutPrivacyHint => 'How we protect your data';

  @override
  String get aboutFaqHint => 'Frequently asked questions';

  @override
  String get aboutSupportHint => 'Get help from the team';

  @override
  String get supportTitle => 'Support';

  @override
  String get supportEmail => 'Email support';

  @override
  String get supportReplyTime => 'We usually reply within 24 hours';

  @override
  String get supportTelegram => 'Telegram';

  @override
  String get supportStatus => 'Service status';

  @override
  String get supportOperational => 'All systems operational';

  @override
  String get supportEmailCopied => 'Email address copied';

  @override
  String get supportTelegramCopied => 'Telegram handle copied';

  @override
  String get paymentsTitle => 'Payment History';

  @override
  String get paymentsLoading => 'Loading payments…';

  @override
  String get paymentsEmpty => 'No payments yet';

  @override
  String get paymentsEmptyHint =>
      'Your payment history will appear here after the first purchase.';

  @override
  String get consentTitle => 'How Nexa VPN uses your connection';

  @override
  String get consentIntro =>
      'Before you connect, here is exactly what this app does with your network traffic.';

  @override
  String get consentPoint1Title => 'It creates a VPN tunnel';

  @override
  String get consentPoint1Body =>
      'Nexa VPN uses the Android VpnService to route your device traffic through a server you choose. Android will ask you to allow this the first time you connect.';

  @override
  String get consentPoint2Title => 'Your traffic is encrypted';

  @override
  String get consentPoint2Body =>
      'Data sent between your device and our server is encrypted. We cannot read the contents of your traffic.';

  @override
  String get consentPoint3Title => 'We keep no activity logs';

  @override
  String get consentPoint3Body =>
      'We do not record the websites you visit, your DNS queries, or the addresses you connect to. We store your account details, session times and data volume to enforce your plan limits.';

  @override
  String get consentPoint4Title => 'Nothing is sold to advertisers';

  @override
  String get consentPoint4Body =>
      'We do not sell personal data and the app contains no third-party advertising trackers.';

  @override
  String get consentReadPolicy => 'Read the full Privacy Policy';

  @override
  String get consentAgree => 'I understand and agree';

  @override
  String get consentDecline => 'Not now';

  @override
  String get consentRequired => 'You need to accept this to use the VPN.';

  @override
  String get keyEntryTitle => 'I have a key';

  @override
  String get keyEntrySubtitle =>
      'Enter a Nexa code, a vless:// link, or a subscription link from any provider';

  @override
  String get keyEntryHint => 'NEXA-XXXX-XXXX, vless://… or https://…';

  @override
  String get keyEntryLabel => 'Access key';

  @override
  String get keyEntryActivate => 'Activate';

  @override
  String get keyEntryPasteFromClipboard => 'Paste from clipboard';

  @override
  String get keyEntryScanQr => 'Scan QR code';

  @override
  String get keyEntryBuyInstead => 'Buy access';

  @override
  String get keyEntryNoKeyYet => 'Don\'t have a key?';

  @override
  String get keyEntryDetectedNexa => 'Nexa access code';

  @override
  String get keyEntryDetectedVless => 'External VLESS key';

  @override
  String get keyEntryErrorEmpty => 'Enter a key or paste a link';

  @override
  String get keyEntryErrorUnknown =>
      'Unrecognised format. Use a NEXA-XXXX-XXXX code, a vless:// link, or a subscription link.';

  @override
  String get keyEntryErrorUnsupportedScheme =>
      'Only vless:// links are supported by this app.';

  @override
  String get keyEntryErrorNotFound => 'Code not found. Check for typos.';

  @override
  String get keyEntryErrorRevoked => 'This code has been revoked.';

  @override
  String get keyEntryErrorExpired => 'This code has expired.';

  @override
  String get keyEntryErrorUsed =>
      'This code is already used on another device.';

  @override
  String get keyEntrySuccessNexa => 'Access activated';

  @override
  String get keyEntrySuccessVless => 'Key imported';

  @override
  String get keyEntryImportedTitle => 'Imported keys';

  @override
  String get keyEntryImportedEmpty => 'No imported keys yet';

  @override
  String get keyEntryRemove => 'Remove';

  @override
  String get keyEntryLocalOnly =>
      'Stored on this device only — never sent to Nexa servers.';

  @override
  String get keyEntryDetectedSubscription => 'Provider subscription';

  @override
  String keyEntrySuccessSubscription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers imported',
      one: '1 server imported',
    );
    return '$_temp0';
  }

  @override
  String get keyEntryErrorUnsupportedScheme2 =>
      'Only vless:// links and https:// subscriptions are supported.';

  @override
  String get keyEntryOpen => 'I have a key';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get serversSearchByName => 'Search by name or host';

  @override
  String get serversSearchByCity => 'Search country or city';

  @override
  String get accessKeysHeader => 'ACCESS KEYS';

  @override
  String get accessNoActiveWarning => 'No active access — renew your subscription to activate a key.';

  @override
  String get accessGenerateHintLong => 'Get access to generate your personal key — usable in the Nexa app and any compatible client.';

  @override
  String get accessStatusActive => 'ACTIVE';

  @override
  String get accessStatusExpired => 'EXPIRED';

  @override
  String get accessStatusRevoked => 'REVOKED';

  @override
  String get accessLastUsed => 'last used';

  @override
  String get accessExpires => 'expires';

  @override
  String get accessDevice => 'device';

  @override
  String get accessDevices => 'devices';

  @override
  String get accessOfflineMessage => 'Cannot reach the server. Your access data will appear once the connection is back.';

  @override
  String get identityTitle => 'My Code';

  @override
  String get identitySubtitle => 'Instead of login and password';

  @override
  String get identityYourId => 'Your identifier';

  @override
  String get identityCopy => 'Copy';

  @override
  String get identityCodeCopied => 'Code copied';

  @override
  String get identitySaveNow => 'Save the code right now';

  @override
  String get identitySaveBody => 'This is the only way to restore paid access on another phone. We don\'t know your email and can\'t restore the code: we simply don\'t have it.\n\nWrite it down on paper or save it in a password manager.';

  @override
  String get identityTransferTitle => 'Transferring access?';

  @override
  String get identityTransferBody => 'If you have a code from a previous device, enter it — this code will be replaced.';

  @override
  String get identityEnterOther => 'Enter another code';

  @override
  String get identityDialogTitle => 'Enter another code';

  @override
  String get identityDialogBody => 'Enter the code saved on another device. The current code will be replaced.';

  @override
  String get identityApply => 'Apply';

  @override
  String get identityCodeApplied => 'Code applied';

  @override
  String get identityCodeRejected => 'Code didn\'t match';

  @override
  String get identityCode16Chars => 'Code must contain 16 characters';

  @override
  String get identityErrorTitle => 'Couldn\'t read the code';

  @override
  String get premiumChoosePlan => 'CHOOSE YOUR PLAN';

  @override
  String serversSwitchError(String error) => 'Failed to switch: $error';

  @override
  String get serversEmptyTitle => 'No servers yet';

  @override
  String get serversEmptyBody => 'Servers appear here once you add a key or a provider subscription. Nothing is shown that you cannot connect to.';

  @override
  String serversReconnected(String label) => 'Reconnected via $label';

  @override
  String serversSelected(String label) => 'Selected $label';

  @override
  String get serversAll => 'ALL SERVERS';

  @override
  String get serversNoMatch => 'Nothing matches that search.';

  @override
  String get serversAddKey => 'Add a key';

  @override
  String get serversConnected => 'Connected';

  @override
  String get serversSelectedStatus => 'Selected';

  @override
  String serversAvailable(int count) => '$count available from your key';

  @override
  String get adminOwnerSection => 'OWNER';

  @override
  String get adminTitle => 'Issue access codes';

  @override
  String get adminSubtitle => 'Create codes for sale and view all keys';

  @override
  String get adminNoAccess => 'This account does not have admin rights';

  @override
  String adminIssueFailed(String error) => 'Failed to issue code: $error';

  @override
  String get adminDurationForever => 'Forever';

  @override
  String get adminDuration30Days => '30 days';

  @override
  String get adminDuration90Days => '90 days';

  @override
  String get adminDuration1Year => '1 year';

  @override
  String adminDurationDays(int count) => '$count days';

  @override
  String get adminOwnerOnly => 'This section is only available to the app owner.';

  @override
  String get adminAllKeys => 'All keys';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminNameLabel => 'Name (optional)';

  @override
  String get adminNameHint => 'e.g. Client #1';

  @override
  String get adminDuration => 'Duration';

  @override
  String get adminIssuing => 'Issuing…';

  @override
  String get adminIssue => 'Issue code';

  @override
  String get adminCodeIssued => 'Code issued — give it to the buyer';

  @override
  String get adminCopyCode => 'Copy code';

  @override
  String adminLoadFailed(String error) => 'Failed to load keys. Make sure the backend is running.\n$error';

  @override
  String get adminNoKeys => 'No keys yet.';

  @override
  String get adminUntil => 'until';

  @override
  String get adminLifetime => 'lifetime';

  @override
  String get adminCopy => 'Copy';

  @override
  String get adminKeyIssue => 'Issue keys';

  @override
  String get adminKeyIssueHint => 'Create codes for sale and view all keys';

  @override
  String get profileLoadError => 'Failed to load subscription data. Check your connection.';

  @override
  String get notificationsLoadError => 'Failed to load notifications. Check your connection.';
}
