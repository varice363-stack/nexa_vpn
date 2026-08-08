import '../../models/changelog_entry.dart';
import '../../models/faq_entry.dart';

/// Static content: FAQ, changelog, legal and support copy.
/// Backend-driven versions should replace these datasources later.
abstract final class StaticContent {
  static const List<FaqEntry> faq = [
    FaqEntry(
      question: 'Is my traffic encrypted?',
      answer: 'Yes. All traffic is encapsulated in an encrypted tunnel using '
          'the protocol selected in Settings (WireGuard, OpenVPN or IKEv2). '
          'Nexa VPN operates a strict no-logs policy: we never store traffic '
          'content, DNS queries or browsing history.',
    ),
    FaqEntry(
      question: 'How many devices can I use?',
      answer: 'The free tier supports 1 device. Premium plans unlock 5–10 '
          'devices, and Lifetime covers unlimited devices with a single '
          'account.',
    ),
    FaqEntry(
      question: 'What does "no-logs" mean?',
      answer: 'We do not collect, store or share information about the '
          'websites you visit, files you download or content you stream. '
          'Connection timestamps are used only for plan enforcement and are '
          'anonymized.',
    ),
    FaqEntry(
      question: 'Why is my connection slower through a VPN?',
      answer: 'Encryption and routing add overhead, and the distance to the '
          'server matters. Use the Fastest filter in the Servers screen to '
          'pick the lowest-ping location, and prefer WireGuard for the best '
          'throughput.',
    ),
    FaqEntry(
      question: 'Can I use Nexa VPN for streaming?',
      answer: 'Yes. Premium servers are optimized for 4K streaming. If a '
          'streaming service blocks a location, try a nearby city or contact '
          'support.',
    ),
    FaqEntry(
      question: 'How do I cancel my subscription?',
      answer: 'Subscriptions are managed through the store you purchased '
          'from (App Store / Google Play). Cancelling takes effect at the end '
          'of the current billing period.',
    ),
  ];

  static const List<ChangelogEntry> changelog = [
    ChangelogEntry(
      version: '1.0.0',
      date: 'Aug 2026',
      notes: [
        'Initial release',
        'Full server catalog with search, favorites and Fastest/Premium filters',
        'Connection flow with live statistics',
        'Statistics, diagnostics, logs and support screens',
        'Premium subscription UI',
        'Glassmorphism dark design system',
      ],
    ),
  ];

  static const List<(String, String)> privacySections = [
    ('1. Information we process',
        'Nexa VPN is designed as a no-logs service. We do not track your '
        'browsing activity, DNS queries, or the content of your traffic. '
        'The only data processed locally is your account identity and '
        'device preferences, which never leave your device.'),
    ('2. Local data',
        'Settings, favorites, session history and profile data are stored '
        'exclusively on your device. Secrets such as credentials are kept in '
        'the platform secure storage (Keychain / Keystore).'),
    ('3. Network data',
        'To operate the VPN we must process, in real time, the encrypted '
        'packets you send and receive. This processing is transient and is '
        'not logged, stored or shared.'),
    ('4. Payments',
        'Payments are processed by the app store (App Store / Google Play). '
        'Nexa VPN never receives or stores your payment details.'),
    ('5. Third parties',
        'We do not sell personal data. We do not use third-party advertising '
        'trackers in the app.'),
    ('6. Changes',
        'This policy may be updated; the current version is always available '
        'in the app under About → Privacy Policy.'),
  ];

  static const String supportEmail = 'support@nexavpn.app';
  static const String supportTelegram = '@nexavpn_support';
}
