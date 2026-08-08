import '../domain/repositories/notification_repository.dart';
import '../models/app_notification.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [NotificationRepository] backed by the Nexa VPN API.
///
/// Maps the backend `Notification` (title/body/type/read/createdAt) onto
/// the existing client [AppNotification] model — no new model needed.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<AppNotification>> getMyNotifications() async {
    final data = await _api.get('/notifications/me');
    if (data is! List) {
      throw const ApiException('Unexpected notifications response',
          code: 'BAD_RESPONSE');
    }
    return data
        .map((item) => _toAppNotification(Map<String, Object?>.from(item as Map)))
        .toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _api.patch('/notifications/me/read-all');
  }

  AppNotification _toAppNotification(Map<String, Object?> json) {
    final createdAt = json['createdAt'] as String?;
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: createdAt == null
          ? DateTime.now()
          : DateTime.tryParse(createdAt) ?? DateTime.now(),
      icon: _iconFromType(json['type'] as String?),
      read: json['read'] as bool? ?? false,
    );
  }

  AppNotificationIcon _iconFromType(String? type) => switch (type) {
        'connection' => AppNotificationIcon.connection,
        'security' => AppNotificationIcon.security,
        'promo' => AppNotificationIcon.promo,
        'system' => AppNotificationIcon.system,
        _ => AppNotificationIcon.info,
      };
}
