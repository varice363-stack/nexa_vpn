import 'dart:convert';

import '../../domain/repositories/session_manager.dart';
import '../../models/connection_session.dart';
import '../datasources/local_settings_datasource.dart';

/// Session history persisted as a JSON list in local settings.
///
class SessionManagerImpl implements SessionManager {
  SessionManagerImpl(this._local);

  final LocalSettingsDatasource _local;

  static const _kSessions = 'history.sessions';

  @override
  Future<List<ConnectionSession>> getSessions() async {
    final raw = _local.sessionJsons;
    final sessions = <ConnectionSession>[];
    for (final json in raw) {
      try {
        sessions.add(
          ConnectionSession.fromJson(
            Map<String, Object?>.from(jsonDecode(json) as Map),
          ),
        );
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  @override
  Future<void> addSession(ConnectionSession session) async {
    final raw = _local.sessionJsons.toList();
    raw.add(jsonEncode(session.toJson()));
    // Keep the newest 60 sessions.
    if (raw.length > 60) raw.removeRange(0, raw.length - 60);
    await _local.setStringList(_kSessions, raw);
  }

  @override
  Future<void> clear() async => _local.remove(_kSessions);
}
