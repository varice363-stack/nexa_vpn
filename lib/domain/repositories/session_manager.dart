import '../../models/connection_session.dart';

/// Persistence of completed VPN sessions (history for statistics).
abstract class SessionManager {
  Future<List<ConnectionSession>> getSessions();
  Future<void> addSession(ConnectionSession session);
  Future<void> clear();
}
