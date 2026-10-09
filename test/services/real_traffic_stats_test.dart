import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/core/utils/app_logger.dart';
import 'package:morok_vpn/domain/repositories/session_manager.dart';
import 'package:morok_vpn/domain/services/vpn_service.dart';
import 'package:morok_vpn/models/connection_session.dart';
import 'package:morok_vpn/models/connection_source.dart';
import 'package:morok_vpn/models/tunnel_traffic.dart';
import 'package:morok_vpn/models/vpn_status.dart';
import 'package:morok_vpn/services/vpn/connection_manager_impl.dart';

/// «Загрузка» и «Отдача» на главном экране раньше генерировались самим
/// приложением (60–180 Мбит/с, выдуманные байты). Теперь они берутся из
/// счётчиков туннеля. Без подключения и без счётчиков — нули, а не цифры.

class _FakeVpnService implements VpnService {
  final StreamController<VpnStatus> _statuses =
      StreamController<VpnStatus>.broadcast();
  final StreamController<TunnelTraffic> _traffic =
      StreamController<TunnelTraffic>.broadcast();

  @override
  Stream<VpnStatus> get statuses => _statuses.stream;

  @override
  Stream<TunnelTraffic> get traffic => _traffic.stream;

  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  ConnectionSource? get activeSource => null;

  @override
  Future<void> connect(ConnectionSource source) async {}

  @override
  Future<void> disconnect() async {}

  void setStatus(VpnStatus status) => _statuses.add(status);

  void setTraffic(TunnelTraffic traffic) => _traffic.add(traffic);
}

class _MemorySessions implements SessionManager {
  final List<ConnectionSession> saved = [];

  @override
  Future<List<ConnectionSession>> getSessions() async => List.of(saved);

  @override
  Future<void> addSession(ConnectionSession session) async => saved.add(session);

  @override
  Future<void> clear() async => saved.clear();
}

void main() {
  testWidgets('без счётчиков туннеля скорость и объём равны нулю', (tester) async {
    final service = _FakeVpnService();
    final manager = ConnectionManagerImpl(logger: AppLogger())
      ..bind(service, _MemorySessions());

    service.setStatus(VpnStatus.connected);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(manager.current.speedDown, 0);
    expect(manager.current.speedUp, 0);
    expect(manager.current.bytesDown, 0);
    expect(manager.current.bytesUp, 0);
    manager.dispose();
  });

  testWidgets('счётчики туннеля попадают на экран как есть, скорость в Мбит/с',
      (tester) async {
    final service = _FakeVpnService();
    final manager = ConnectionManagerImpl(logger: AppLogger())
      ..bind(service, _MemorySessions());

    service.setStatus(VpnStatus.connected);
    await tester.pump();
    service.setTraffic(const TunnelTraffic(
      uploadBytes: 500000,
      downloadBytes: 2000000,
      uploadBytesPerSec: 125000, // 1 Мбит/с
      downloadBytesPerSec: 1250000, // 10 Мбит/с
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(manager.current.bytesDown, 2000000);
    expect(manager.current.bytesUp, 500000);
    expect(manager.current.speedDown, closeTo(10.0, 0.001));
    expect(manager.current.speedUp, closeTo(1.0, 0.001));
    manager.dispose();
  });

  testWidgets('счётчики до подключения игнорируются', (tester) async {
    final service = _FakeVpnService();
    final manager = ConnectionManagerImpl(logger: AppLogger())
      ..bind(service, _MemorySessions());

    service.setTraffic(const TunnelTraffic(
      downloadBytes: 9000000,
      downloadBytesPerSec: 5000000,
    ));
    await tester.pump();

    expect(manager.current.bytesDown, 0);
    expect(manager.current.speedDown, 0);
    manager.dispose();
  });

  testWidgets('после отключения скорость обнуляется и цифры не растут сами',
      (tester) async {
    final service = _FakeVpnService();
    final manager = ConnectionManagerImpl(logger: AppLogger())
      ..bind(service, _MemorySessions());

    service.setStatus(VpnStatus.connected);
    await tester.pump();
    service.setTraffic(const TunnelTraffic(
      downloadBytes: 2000000,
      downloadBytesPerSec: 1250000,
    ));
    await tester.pump();

    service.setStatus(VpnStatus.disconnected);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(manager.current.speedDown, 0);
    expect(manager.current.bytesDown, 2000000);
    manager.dispose();
  });
}
