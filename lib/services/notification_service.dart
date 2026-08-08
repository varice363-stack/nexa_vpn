import 'dart:async';

import '../models/app_notification.dart';

/// In-app notification feed.
///
/// PUSH INTEGRATION (TODO — external infrastructure):
///   * `firebase_messaging` (FCM) for remote pushes;
///   * `flutter_local_notifications` for scheduled/local system alerts.
/// Until then the service exposes an in-app feed consumed by the
/// Notifications screen and seeded by app events.
class NotificationService {
  NotificationService();

  final StreamController<AppNotification> _controller =
      StreamController<AppNotification>.broadcast();

  int _seq = 0;

  Stream<AppNotification> get notifications => _controller.stream;

  void push({
    required String title,
    required String body,
    AppNotificationIcon icon = AppNotificationIcon.info,
  }) {
    final notification = AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      icon: icon,
    );
    _controller.add(notification);
  }

  void dispose() => _controller.close();
}
