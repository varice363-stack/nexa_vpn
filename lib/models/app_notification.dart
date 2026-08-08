/// In-app notification feed item.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.icon = AppNotificationIcon.info,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final AppNotificationIcon icon;
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      timestamp: timestamp,
      icon: icon,
      read: read ?? this.read,
    );
  }
}

enum AppNotificationIcon {
  connection,
  security,
  promo,
  system,
  info,
}
