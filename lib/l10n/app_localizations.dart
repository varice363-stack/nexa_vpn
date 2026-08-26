import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Nexa VPN'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Private • Secure • Fast'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get navServers;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get commonSignIn;

  /// No description provided for @commonCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get commonCreateAccount;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Please check your network.'**
  String get errorNetwork;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'One-tap protection'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In en, this message translates to:
  /// **'Connect with a single tap. Nexa VPN works silently in the background and keeps your session alive.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Military-grade encryption'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In en, this message translates to:
  /// **'Your traffic is protected with the modern VLESS protocol over Xray REALITY.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Blazing fast speeds'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In en, this message translates to:
  /// **'A strict no-logs policy keeps your activity private — always.'**
  String get onboardingBody3;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Your connection is protected'**
  String get homeGreeting;

  /// No description provided for @homeNotificationsSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications are coming soon'**
  String get homeNotificationsSoon;

  /// No description provided for @powerTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get powerTapToConnect;

  /// No description provided for @powerTapToDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to disconnect'**
  String get powerTapToDisconnect;

  /// No description provided for @powerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get powerConnecting;

  /// No description provided for @powerDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get powerDisconnecting;

  /// No description provided for @powerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get powerNotConnected;

  /// No description provided for @powerConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get powerConnectionError;

  /// No description provided for @powerConnectedFor.
  ///
  /// In en, this message translates to:
  /// **'Connected • {duration}'**
  String powerConnectedFor(String duration);

  /// No description provided for @statsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get statsDownload;

  /// No description provided for @statsUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get statsUpload;

  /// No description provided for @statsPing.
  ///
  /// In en, this message translates to:
  /// **'Ping'**
  String get statsPing;

  /// No description provided for @accessActive.
  ///
  /// In en, this message translates to:
  /// **'Access active'**
  String get accessActive;

  /// No description provided for @accessChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking access…'**
  String get accessChecking;

  /// No description provided for @accessNoKeyYet.
  ///
  /// In en, this message translates to:
  /// **'No access key yet'**
  String get accessNoKeyYet;

  /// No description provided for @accessNoActiveKey.
  ///
  /// In en, this message translates to:
  /// **'No active key'**
  String get accessNoActiveKey;

  /// No description provided for @accessGenerateHint.
  ///
  /// In en, this message translates to:
  /// **'Generate a key to use Nexa on any device'**
  String get accessGenerateHint;

  /// No description provided for @accessGetAccess.
  ///
  /// In en, this message translates to:
  /// **'Get access'**
  String get accessGetAccess;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your devices and keys'**
  String get loginSubtitle;

  /// No description provided for @loginEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get loginEnterEmail;

  /// No description provided for @loginEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginEnterPassword;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get loginInvalidEmail;

  /// No description provided for @loginBadCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get loginBadCredentials;

  /// No description provided for @loginBlocked.
  ///
  /// In en, this message translates to:
  /// **'This account is blocked. Contact support.'**
  String get loginBlocked;

  /// No description provided for @loginContinueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get loginContinueAsGuest;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One account for all your devices'**
  String get registerSubtitle;

  /// No description provided for @registerEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get registerEnterName;

  /// No description provided for @registerEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get registerEnterPassword;

  /// No description provided for @registerConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registerConfirmPassword;

  /// No description provided for @registerConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get registerConfirmHint;

  /// No description provided for @registerPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerPasswordsMismatch;

  /// No description provided for @registerMinChars.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get registerMinChars;

  /// No description provided for @registerMaxChars.
  ///
  /// In en, this message translates to:
  /// **'At most 72 characters'**
  String get registerMaxChars;

  /// No description provided for @registerNeedDigit.
  ///
  /// In en, this message translates to:
  /// **'Add at least one digit'**
  String get registerNeedDigit;

  /// No description provided for @registerNeedLetter.
  ///
  /// In en, this message translates to:
  /// **'Add at least one letter'**
  String get registerNeedLetter;

  /// No description provided for @registerAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get registerAlreadyHaveAccount;

  /// No description provided for @registerEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try signing in.'**
  String get registerEmailTaken;

  /// No description provided for @registerInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input. Check the form and try again.'**
  String get registerInvalidInput;

  /// No description provided for @serversFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get serversFilterAll;

  /// No description provided for @serversFilterFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get serversFilterFastest;

  /// No description provided for @serversFilterPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get serversFilterPremium;

  /// No description provided for @serversFilterSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get serversFilterSaved;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Connection events and offers will appear here.'**
  String get notificationsEmptyBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tunnel and privacy preferences'**
  String get settingsSubtitle;

  /// No description provided for @settingsSectionConnection.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION'**
  String get settingsSectionConnection;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & SECURITY'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionBehavior.
  ///
  /// In en, this message translates to:
  /// **'BEHAVIOR'**
  String get settingsSectionBehavior;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'DATA'**
  String get settingsSectionData;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'APP'**
  String get settingsSectionApp;

  /// No description provided for @settingsAutoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect'**
  String get settingsAutoConnect;

  /// No description provided for @settingsAutoConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Connect to the fastest server on app launch'**
  String get settingsAutoConnectHint;

  /// No description provided for @settingsProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get settingsProtocol;

  /// No description provided for @settingsProtocolHint.
  ///
  /// In en, this message translates to:
  /// **'Tunnel transport protocol'**
  String get settingsProtocolHint;

  /// No description provided for @settingsKillSwitch.
  ///
  /// In en, this message translates to:
  /// **'Kill switch'**
  String get settingsKillSwitch;

  /// No description provided for @settingsKillSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Block all traffic if the tunnel drops'**
  String get settingsKillSwitchHint;

  /// No description provided for @settingsDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get settingsDns;

  /// No description provided for @settingsDnsHint.
  ///
  /// In en, this message translates to:
  /// **'DNS resolution mode'**
  String get settingsDnsHint;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Connection events and app alerts'**
  String get settingsNotificationsHint;

  /// No description provided for @settingsClearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear diagnostic logs'**
  String get settingsClearLogs;

  /// No description provided for @settingsClearLogsHint.
  ///
  /// In en, this message translates to:
  /// **'Erase the in-app event buffer'**
  String get settingsClearLogsHint;

  /// No description provided for @settingsLogsCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared'**
  String get settingsLogsCleared;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Nexa VPN'**
  String get settingsAbout;

  /// No description provided for @settingsAboutHint.
  ///
  /// In en, this message translates to:
  /// **'Version, privacy policy, changelog'**
  String get settingsAboutHint;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get settingsLanguageHint;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRussian;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get commonEdit;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @commonUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get commonUpgrade;

  /// No description provided for @commonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// No description provided for @commonOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// No description provided for @commonPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get commonPremium;

  /// No description provided for @commonFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get commonFreePlan;

  /// No description provided for @commonDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get commonDevices;

  /// No description provided for @commonProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get commonProtocol;

  /// No description provided for @commonServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get commonServer;

  /// No description provided for @commonAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get commonAddress;

  /// No description provided for @commonExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get commonExpires;

  /// No description provided for @bannerCarousel.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get bannerCarousel;

  /// No description provided for @bannerDuration.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String bannerDuration(int seconds);

  /// No description provided for @bannerTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get bannerTapToOpen;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuest;

  /// No description provided for @profileGuestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest mode'**
  String get profileGuestMode;

  /// No description provided for @profileGuestHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync devices, keys and subscriptions'**
  String get profileGuestHint;

  /// No description provided for @profilePremiumMember.
  ///
  /// In en, this message translates to:
  /// **'Premium member'**
  String get profilePremiumMember;

  /// No description provided for @profileAllUnlocked.
  ///
  /// In en, this message translates to:
  /// **'All features unlocked'**
  String get profileAllUnlocked;

  /// No description provided for @profileUpgradeHint.
  ///
  /// In en, this message translates to:
  /// **'Upgrade for unlimited data and 4K streaming'**
  String get profileUpgradeHint;

  /// No description provided for @profileNexaPremium.
  ///
  /// In en, this message translates to:
  /// **'Nexa Premium'**
  String get profileNexaPremium;

  /// No description provided for @profileMyAccess.
  ///
  /// In en, this message translates to:
  /// **'My Access'**
  String get profileMyAccess;

  /// No description provided for @profileMyAccessHint.
  ///
  /// In en, this message translates to:
  /// **'Subscription and access keys'**
  String get profileMyAccessHint;

  /// No description provided for @profileSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get profileSessions;

  /// No description provided for @profilePaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get profilePaymentHistory;

  /// No description provided for @profilePaymentHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Checkouts and payments'**
  String get profilePaymentHistoryHint;

  /// No description provided for @profileSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Protocol, kill switch, DNS'**
  String get profileSettingsHint;

  /// No description provided for @profileNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'App events and alerts'**
  String get profileNotificationsHint;

  /// No description provided for @profileSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupport;

  /// No description provided for @profileSupportHint.
  ///
  /// In en, this message translates to:
  /// **'Contact us or read the FAQ'**
  String get profileSupportHint;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// No description provided for @profileAboutHint.
  ///
  /// In en, this message translates to:
  /// **'Version and legal'**
  String get profileAboutHint;

  /// No description provided for @profileMyActivity.
  ///
  /// In en, this message translates to:
  /// **'MY ACTIVITY'**
  String get profileMyActivity;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileAccount;

  /// No description provided for @profileOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get profileOnline;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileMyCode.
  ///
  /// In en, this message translates to:
  /// **'My code'**
  String get profileMyCode;

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out. Welcome back anytime.'**
  String get profileSignedOut;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileChangePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get profileChangePasswordHint;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get profileCurrentPassword;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get profileNewPassword;

  /// No description provided for @profilePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get profilePasswordChanged;

  /// No description provided for @accessTitle.
  ///
  /// In en, this message translates to:
  /// **'My Access'**
  String get accessTitle;

  /// No description provided for @accessLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your access…'**
  String get accessLoading;

  /// No description provided for @accessKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get accessKeys;

  /// No description provided for @accessPremiumAccess.
  ///
  /// In en, this message translates to:
  /// **'Premium access'**
  String get accessPremiumAccess;

  /// No description provided for @accessPremiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get accessPremiumActive;

  /// No description provided for @accessNoActivePlan.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get accessNoActivePlan;

  /// No description provided for @accessNoKeys.
  ///
  /// In en, this message translates to:
  /// **'No access keys yet'**
  String get accessNoKeys;

  /// No description provided for @accessSubscribeHint.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to generate access keys'**
  String get accessSubscribeHint;

  /// No description provided for @accessGetAccessHint.
  ///
  /// In en, this message translates to:
  /// **'Get access to generate your personal key'**
  String get accessGetAccessHint;

  /// No description provided for @accessExpired.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has expired — renew to keep access.'**
  String get accessExpired;

  /// No description provided for @accessOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Your access data will appear once the connection is restored.'**
  String get accessOfflineHint;

  /// No description provided for @vlessActiveConfig.
  ///
  /// In en, this message translates to:
  /// **'Active VLESS configuration'**
  String get vlessActiveConfig;

  /// No description provided for @vlessCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy VLESS'**
  String get vlessCopy;

  /// No description provided for @vlessShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get vlessShowQr;

  /// No description provided for @vlessScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan with any VLESS client'**
  String get vlessScanHint;

  /// No description provided for @vlessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Configuration unavailable'**
  String get vlessUnavailable;

  /// No description provided for @vlessNotReady.
  ///
  /// In en, this message translates to:
  /// **'The assigned server is not ready yet. Please check back shortly.'**
  String get vlessNotReady;

  /// No description provided for @vlessCompatible.
  ///
  /// In en, this message translates to:
  /// **'Works with v2rayNG, Shadowrocket, sing-box and other clients.'**
  String get vlessCompatible;

  /// No description provided for @vlessCopied.
  ///
  /// In en, this message translates to:
  /// **'VLESS configuration copied'**
  String get vlessCopied;

  /// No description provided for @vlessNeverExpires.
  ///
  /// In en, this message translates to:
  /// **'Never (lifetime)'**
  String get vlessNeverExpires;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// No description provided for @premiumLoadingPlans.
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get premiumLoadingPlans;

  /// No description provided for @premiumNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans available'**
  String get premiumNoPlans;

  /// No description provided for @premiumNoPlansHint.
  ///
  /// In en, this message translates to:
  /// **'Check back soon — plans are being prepared.'**
  String get premiumNoPlansHint;

  /// No description provided for @premiumOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Plans will appear once the connection is restored.'**
  String get premiumOfflineHint;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get premiumActive;

  /// No description provided for @premiumSignInToSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Sign in to subscribe'**
  String get premiumSignInToSubscribe;

  /// No description provided for @premiumOpenPaymentPage.
  ///
  /// In en, this message translates to:
  /// **'Open payment page'**
  String get premiumOpenPaymentPage;

  /// No description provided for @premiumPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get premiumPaymentTitle;

  /// No description provided for @premiumPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get premiumPaymentFailed;

  /// No description provided for @premiumPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful — access activated'**
  String get premiumPaymentSuccess;

  /// No description provided for @premiumSecurePaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Payment is processed by a secure provider. Cancel anytime.'**
  String get premiumSecurePaymentNote;

  /// No description provided for @premiumPaymentsComingSoonNote.
  ///
  /// In en, this message translates to:
  /// **'Prices are final. In-app payment is being connected.'**
  String get premiumPaymentsComingSoonNote;

  /// No description provided for @premiumPaymentsComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment is coming soon'**
  String get premiumPaymentsComingSoonTitle;

  /// No description provided for @premiumPaymentsComingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'In-app purchase is not connected yet, so we are not taking payments. Prices above are final. If you already have an access code, activate it now.'**
  String get premiumPaymentsComingSoonBody;

  /// No description provided for @premiumIHaveCode.
  ///
  /// In en, this message translates to:
  /// **'I have an access code'**
  String get premiumIHaveCode;

  /// No description provided for @premiumCheckPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'I have paid — check status'**
  String get premiumCheckPaymentStatus;

  /// No description provided for @premiumGetFor.
  ///
  /// In en, this message translates to:
  /// **'Get Premium — {price}'**
  String premiumGetFor(String price);

  /// No description provided for @premiumPerMonth.
  ///
  /// In en, this message translates to:
  /// **'≈{price}/mo'**
  String premiumPerMonth(String price);

  /// No description provided for @premiumSavings.
  ///
  /// In en, this message translates to:
  /// **'Save {amount}'**
  String premiumSavings(String amount);

  /// No description provided for @premiumDaysOfAccess.
  ///
  /// In en, this message translates to:
  /// **'{days} days of access'**
  String premiumDaysOfAccess(int days);

  /// No description provided for @premiumTrialHint.
  ///
  /// In en, this message translates to:
  /// **'Full access, no card required. One trial per account.'**
  String get premiumTrialHint;

  /// No description provided for @serversTitle.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get serversTitle;

  /// No description provided for @serversLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading locations…'**
  String get serversLoading;

  /// No description provided for @serversFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching servers…'**
  String get serversFetching;

  /// No description provided for @serversCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current server'**
  String get serversCurrent;

  /// No description provided for @serversNotFound.
  ///
  /// In en, this message translates to:
  /// **'No servers found'**
  String get serversNotFound;

  /// No description provided for @serversResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get serversResetFilters;

  /// No description provided for @serversTryDifferent.
  ///
  /// In en, this message translates to:
  /// **'Try a different query or reset the filters'**
  String get serversTryDifferent;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'How we protect your data'**
  String get aboutPrivacyHint;

  /// No description provided for @aboutFaqHint.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get aboutFaqHint;

  /// No description provided for @aboutSupportHint.
  ///
  /// In en, this message translates to:
  /// **'Get help from the team'**
  String get aboutSupportHint;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportTitle;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get supportEmail;

  /// No description provided for @supportReplyTime.
  ///
  /// In en, this message translates to:
  /// **'We usually reply within 24 hours'**
  String get supportReplyTime;

  /// No description provided for @supportTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get supportTelegram;

  /// No description provided for @supportStatus.
  ///
  /// In en, this message translates to:
  /// **'Service status'**
  String get supportStatus;

  /// No description provided for @supportOperational.
  ///
  /// In en, this message translates to:
  /// **'All systems operational'**
  String get supportOperational;

  /// No description provided for @supportEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email address copied'**
  String get supportEmailCopied;

  /// No description provided for @supportTelegramCopied.
  ///
  /// In en, this message translates to:
  /// **'Telegram handle copied'**
  String get supportTelegramCopied;

  /// No description provided for @paymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentsTitle;

  /// No description provided for @paymentsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading payments…'**
  String get paymentsLoading;

  /// No description provided for @paymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get paymentsEmpty;

  /// No description provided for @paymentsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your payment history will appear here after the first purchase.'**
  String get paymentsEmptyHint;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'How Nexa VPN uses your connection'**
  String get consentTitle;

  /// No description provided for @consentIntro.
  ///
  /// In en, this message translates to:
  /// **'Before you connect, here is exactly what this app does with your network traffic.'**
  String get consentIntro;

  /// No description provided for @consentPoint1Title.
  ///
  /// In en, this message translates to:
  /// **'It creates a VPN tunnel'**
  String get consentPoint1Title;

  /// No description provided for @consentPoint1Body.
  ///
  /// In en, this message translates to:
  /// **'Nexa VPN uses the Android VpnService to route your device traffic through a server you choose. Android will ask you to allow this the first time you connect.'**
  String get consentPoint1Body;

  /// No description provided for @consentPoint2Title.
  ///
  /// In en, this message translates to:
  /// **'Your traffic is encrypted'**
  String get consentPoint2Title;

  /// No description provided for @consentPoint2Body.
  ///
  /// In en, this message translates to:
  /// **'Data sent between your device and our server is encrypted. We cannot read the contents of your traffic.'**
  String get consentPoint2Body;

  /// No description provided for @consentPoint3Title.
  ///
  /// In en, this message translates to:
  /// **'We keep no activity logs'**
  String get consentPoint3Title;

  /// No description provided for @consentPoint3Body.
  ///
  /// In en, this message translates to:
  /// **'We do not record the websites you visit, your DNS queries, or the addresses you connect to. We store your account details, session times and data volume to enforce your plan limits.'**
  String get consentPoint3Body;

  /// No description provided for @consentPoint4Title.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sold to advertisers'**
  String get consentPoint4Title;

  /// No description provided for @consentPoint4Body.
  ///
  /// In en, this message translates to:
  /// **'We do not sell personal data and the app contains no third-party advertising trackers.'**
  String get consentPoint4Body;

  /// No description provided for @consentReadPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read the full Privacy Policy'**
  String get consentReadPolicy;

  /// No description provided for @consentAgree.
  ///
  /// In en, this message translates to:
  /// **'I understand and agree'**
  String get consentAgree;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get consentDecline;

  /// No description provided for @consentRequired.
  ///
  /// In en, this message translates to:
  /// **'You need to accept this to use the VPN.'**
  String get consentRequired;

  /// No description provided for @keyEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'I have a key'**
  String get keyEntryTitle;

  /// No description provided for @keyEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a Nexa code, a vless:// link, or a subscription link from any provider'**
  String get keyEntrySubtitle;

  /// No description provided for @keyEntryHint.
  ///
  /// In en, this message translates to:
  /// **'NEXA-XXXX-XXXX, vless://… or https://…'**
  String get keyEntryHint;

  /// No description provided for @keyEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Access key'**
  String get keyEntryLabel;

  /// No description provided for @keyEntryActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get keyEntryActivate;

  /// No description provided for @keyEntryPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get keyEntryPasteFromClipboard;

  /// No description provided for @keyEntryScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get keyEntryScanQr;

  /// No description provided for @keyEntryBuyInstead.
  ///
  /// In en, this message translates to:
  /// **'Buy access'**
  String get keyEntryBuyInstead;

  /// No description provided for @keyEntryNoKeyYet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have a key?'**
  String get keyEntryNoKeyYet;

  /// No description provided for @keyEntryDetectedNexa.
  ///
  /// In en, this message translates to:
  /// **'Nexa access code'**
  String get keyEntryDetectedNexa;

  /// No description provided for @keyEntryDetectedVless.
  ///
  /// In en, this message translates to:
  /// **'External VLESS key'**
  String get keyEntryDetectedVless;

  /// No description provided for @keyEntryErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a key or paste a link'**
  String get keyEntryErrorEmpty;

  /// No description provided for @keyEntryErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unrecognised format. Use a NEXA-XXXX-XXXX code, a vless:// link, or a subscription link.'**
  String get keyEntryErrorUnknown;

  /// No description provided for @keyEntryErrorUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'Only vless:// links are supported by this app.'**
  String get keyEntryErrorUnsupportedScheme;

  /// No description provided for @keyEntryErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Code not found. Check for typos.'**
  String get keyEntryErrorNotFound;

  /// No description provided for @keyEntryErrorRevoked.
  ///
  /// In en, this message translates to:
  /// **'This code has been revoked.'**
  String get keyEntryErrorRevoked;

  /// No description provided for @keyEntryErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired.'**
  String get keyEntryErrorExpired;

  /// No description provided for @keyEntryErrorUsed.
  ///
  /// In en, this message translates to:
  /// **'This code is already used on another device.'**
  String get keyEntryErrorUsed;

  /// No description provided for @keyEntrySuccessNexa.
  ///
  /// In en, this message translates to:
  /// **'Access activated'**
  String get keyEntrySuccessNexa;

  /// No description provided for @keyEntrySuccessVless.
  ///
  /// In en, this message translates to:
  /// **'Key imported'**
  String get keyEntrySuccessVless;

  /// No description provided for @keyEntryImportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Imported keys'**
  String get keyEntryImportedTitle;

  /// No description provided for @keyEntryImportedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No imported keys yet'**
  String get keyEntryImportedEmpty;

  /// No description provided for @keyEntryRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get keyEntryRemove;

  /// No description provided for @keyEntryLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device only — never sent to Nexa servers.'**
  String get keyEntryLocalOnly;

  /// No description provided for @keyEntryDetectedSubscription.
  ///
  /// In en, this message translates to:
  /// **'Provider subscription'**
  String get keyEntryDetectedSubscription;

  /// No description provided for @keyEntrySuccessSubscription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server imported} other{{count} servers imported}}'**
  String keyEntrySuccessSubscription(int count);

  /// No description provided for @keyEntryErrorUnsupportedScheme2.
  ///
  /// In en, this message translates to:
  /// **'Only vless:// links and https:// subscriptions are supported.'**
  String get keyEntryErrorUnsupportedScheme2;

  /// No description provided for @keyEntryOpen.
  ///
  /// In en, this message translates to:
  /// **'I have a key'**
  String get keyEntryOpen;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @serversSearchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name or host'**
  String get serversSearchByName;

  /// No description provided for @serversSearchByCity.
  ///
  /// In en, this message translates to:
  /// **'Search country or city'**
  String get serversSearchByCity;

  /// No description provided for @accessKeysHeader.
  ///
  /// In en, this message translates to:
  /// **'ACCESS KEYS'**
  String get accessKeysHeader;

  /// No description provided for @accessNoActiveWarning.
  ///
  /// In en, this message translates to:
  /// **'No active access — renew your subscription to activate a key.'**
  String get accessNoActiveWarning;

  /// No description provided for @accessGenerateHintLong.
  ///
  /// In en, this message translates to:
  /// **'Get access to generate your personal key — usable in the Nexa app and any compatible client.'**
  String get accessGenerateHintLong;

  /// No description provided for @accessStatusActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get accessStatusActive;

  /// No description provided for @accessStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get accessStatusExpired;

  /// No description provided for @accessStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'REVOKED'**
  String get accessStatusRevoked;

  /// No description provided for @accessLastUsed.
  ///
  /// In en, this message translates to:
  /// **'last used'**
  String get accessLastUsed;

  /// No description provided for @accessExpires.
  ///
  /// In en, this message translates to:
  /// **'expires'**
  String get accessExpires;

  /// No description provided for @accessDevice.
  ///
  /// In en, this message translates to:
  /// **'device'**
  String get accessDevice;

  /// No description provided for @accessDevices.
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get accessDevices;

  /// No description provided for @accessOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Your access data will appear once the connection is back.'**
  String get accessOfflineMessage;

  /// No description provided for @identityTitle.
  ///
  /// In en, this message translates to:
  /// **'My Code'**
  String get identityTitle;

  /// No description provided for @identitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instead of login and password'**
  String get identitySubtitle;

  /// No description provided for @identityYourId.
  ///
  /// In en, this message translates to:
  /// **'Your identifier'**
  String get identityYourId;

  /// No description provided for @identityCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get identityCopy;

  /// No description provided for @identityCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get identityCodeCopied;

  /// No description provided for @identitySaveNow.
  ///
  /// In en, this message translates to:
  /// **'Save the code right now'**
  String get identitySaveNow;

  /// No description provided for @identitySaveBody.
  ///
  /// In en, this message translates to:
  /// **'This is the only way to restore paid access on another phone. We don\'t know your email and can\'t restore the code: we simply don\'t have it.\n\nWrite it down on paper or save it in a password manager.'**
  String get identitySaveBody;

  /// No description provided for @identityTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transferring access?'**
  String get identityTransferTitle;

  /// No description provided for @identityTransferBody.
  ///
  /// In en, this message translates to:
  /// **'If you have a code from a previous device, enter it — this code will be replaced.'**
  String get identityTransferBody;

  /// No description provided for @identityEnterOther.
  ///
  /// In en, this message translates to:
  /// **'Enter another code'**
  String get identityEnterOther;

  /// No description provided for @identityDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter another code'**
  String get identityDialogTitle;

  /// No description provided for @identityDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code saved on another device. The current code will be replaced.'**
  String get identityDialogBody;

  /// No description provided for @identityApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get identityApply;

  /// No description provided for @identityCodeApplied.
  ///
  /// In en, this message translates to:
  /// **'Code applied'**
  String get identityCodeApplied;

  /// No description provided for @identityCodeRejected.
  ///
  /// In en, this message translates to:
  /// **'Code didn\'t match'**
  String get identityCodeRejected;

  /// No description provided for @identityCode16Chars.
  ///
  /// In en, this message translates to:
  /// **'Code must contain 16 characters'**
  String get identityCode16Chars;

  /// No description provided for @identityErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the code'**
  String get identityErrorTitle;

  /// No description provided for @premiumChoosePlan.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR PLAN'**
  String get premiumChoosePlan;

  /// No description provided for @serversSwitchError.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch: {error}'**
  String serversSwitchError(String error);

  /// No description provided for @serversEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get serversEmptyTitle;

  /// No description provided for @serversEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Servers appear here once you add a key or a provider subscription. Nothing is shown that you cannot connect to.'**
  String get serversEmptyBody;

  /// No description provided for @serversReconnected.
  ///
  /// In en, this message translates to:
  /// **'Reconnected via {label}'**
  String serversReconnected(String label);

  /// No description provided for @serversSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected {label}'**
  String serversSelected(String label);

  /// No description provided for @serversAll.
  ///
  /// In en, this message translates to:
  /// **'ALL SERVERS'**
  String get serversAll;

  /// No description provided for @serversNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that search.'**
  String get serversNoMatch;

  /// No description provided for @serversAddKey.
  ///
  /// In en, this message translates to:
  /// **'Add a key'**
  String get serversAddKey;

  /// No description provided for @serversConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get serversConnected;

  /// No description provided for @serversSelectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get serversSelectedStatus;

  /// No description provided for @serversAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available from your key'**
  String serversAvailable(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
