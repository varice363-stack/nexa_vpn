import 'dart:async';

import '../../models/connection_stats.dart';
import '../../domain/repositories/session_manager.dart';
import '../../domain/services/vpn_service.dart';

/// Tracks a live connection session: duration, transferred bytes and
/// simulated throughput; persists completed sessions via [SessionManager].
abstract class ConnectionManager {
  /// Live metrics, updated ~1 Hz.
  Stream<ConnectionStats> get stats;

  ConnectionStats get current;

  /// Starts observing [service]; must be called once before use.
  void bind(VpnService service, SessionManager sessions);

  void dispose();
}
