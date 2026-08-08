import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../domain/repositories/session_manager.dart';
import '../../models/connection_session.dart';
import '../datasources/local_settings_datasource.dart';

/// Session history persisted as a JSON list in local settings.
///
/// Seeds demo history on first run so the Statistics screen has content
/// until real sessions accumulate.
class SessionManagerImpl implements SessionManager {
  SessionManagerImpl(this._local, {this.seedDemo = true}) {
    if (seedDemo && _local.sessionJsons.isEmpty) _seedDemo();
  }

  final LocalSettingsDatasource _local;
  final bool seedDemo;

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

  void _seedDemo() {
    final now = DateTime.now();
    const serverNames = [
      'Germany · Frankfurt',
      'Turkey · Istanbul',
      'Netherlands · Amsterdam',
      'United Kingdom · London',
      'United States · New York',
      'Sweden · Stockholm',
      'Switzerland · Zurich',
      'Japan · Tokyo',
    ];
    final sessions = <ConnectionSession>[];
    for (var i = 0; i < AppConstants.demoSeedSessions; i++) {
      final start = now.subtract(Duration(days: 6 - (i % 7), hours: i * 3));
      final minutes = 12 + (i * 37) % 180;
      final end = start.add(Duration(minutes: minutes));
      final mbDown = 80 + (i * 641) % 2400;
      sessions.add(
        ConnectionSession(
          serverId: 'demo-$i',
          serverName: serverNames[i % serverNames.length],
          startedAt: start,
          endedAt: end,
          bytesDown: mbDown * 1024 * 1024,
          bytesUp: mbDown ~/ 4 * 1024 * 1024,
        ),
      );
    }
    final raw = sessions.map((s) => jsonEncode(s.toJson())).toList();
    _local.setStringList(_kSessions, raw);
  }
}
