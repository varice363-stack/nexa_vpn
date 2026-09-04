/// Notification icon type.
enum AppNotificationIcon {
  info,
  connection,
  security,
  promo,
  system,
}

/// In-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.body = '',
    this.icon = AppNotificationIcon.info,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final String body;
  final DateTime timestamp;
  final AppNotificationIcon icon;
  final bool read;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? body,
    DateTime? timestamp,
    AppNotificationIcon? icon,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      icon: icon ?? this.icon,
      read: read ?? this.read,
    );
  }

  @override
  String toString() => 'AppNotification($id, $title)';
}
