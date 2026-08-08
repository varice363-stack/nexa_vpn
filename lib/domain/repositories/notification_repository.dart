import '../../models/app_notification.dart';

/// In-app notifications contract (backend `/notifications`).
abstract class NotificationRepository {
  /// GET /notifications/me — own + broadcast notifications.
  Future<List<AppNotification>> getMyNotifications();

  /// PATCH /notifications/:id/read
  Future<void> markRead(String id);

  /// PATCH /notifications/me/read-all
  Future<void> markAllRead();
}
