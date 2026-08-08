import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// In-app notification feed.
///
/// Remote notifications come from the backend (`GET /notifications/me`);
/// local app events (connection, premium) are pushed through
/// [NotificationService] and merged on top. On API failure the feed
/// still works with local events only.
final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, List<AppNotification>>(
  NotificationNotifier.new,
);

class NotificationNotifier extends AsyncNotifier<List<AppNotification>> {
  StreamSubscription<AppNotification>? _localSub;
  List<AppNotification> _local = const [];
  List<AppNotification> _remote = const [];

  @override
  Future<List<AppNotification>> build() async {
    final service = ref.watch(notificationServiceProvider);
    _localSub = service.notifications.listen((notification) {
      _local = [notification, ..._local];
      state = AsyncData([..._local, ..._remote]);
    });
    ref.onDispose(() => _localSub?.cancel());

    try {
      _remote = await ref.watch(notificationRepositoryProvider)
          .getMyNotifications();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn(
            'Notifications API unavailable ($e) — local feed only',
            source: 'api',
          );
    }

    // Welcome seed on first run, so the screen is never empty.
    if (_local.isEmpty && _remote.isEmpty) {
      service.push(
        title: 'Welcome to Nexa VPN',
        body: 'Your connection is protected. Pick a server to get started.',
        icon: AppNotificationIcon.security,
      );
    }

    return [..._local, ..._remote];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      _remote = await ref
          .read(notificationRepositoryProvider)
          .getMyNotifications();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Notifications refresh failed: $e',
          source: 'api');
    }
    state = AsyncData([..._local, ..._remote]);
  }

  Future<void> markAllRead() async {
    state = AsyncData([
      for (final n in state.value ?? const <AppNotification>[])
        n.copyWith(read: true),
    ]);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('markAllRead failed: $e', source: 'api');
    }
  }

  Future<void> markRead(String id) async {
    state = AsyncData([
      for (final n in state.value ?? const <AppNotification>[])
        n.id == id ? n.copyWith(read: true) : n,
    ]);
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('markRead failed: $e', source: 'api');
    }
  }

  void clear() {
    _local = const [];
    _remote = const [];
    state = const AsyncData([]);
  }
}

/// Number of unread notifications.
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref
          .watch(notificationProvider)
          .value
          ?.where((n) => !n.read)
          .length ??
      0,
);
