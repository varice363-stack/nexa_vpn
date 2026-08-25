import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:nexa_vpn/core/utils/app_logger.dart';
import 'package:nexa_vpn/domain/services/tunnel_manager.dart';
import 'package:nexa_vpn/models/connection_source.dart';
import 'package:nexa_vpn/models/vpn_config.dart';
import 'package:nexa_vpn/models/vpn_status.dart';
import 'package:nexa_vpn/services/vpn/vpn_service_impl.dart';

/// Stage B: the tunnel is driven by the key itself.
///
/// Before this, `startTunnel` took a catalog `Server` (country, ping, load) —
/// there was nowhere to put a `vless://` link, so an imported key could never
/// reach the tunnel no matter what the UI did. These tests pin down that the
/// endpoint now travels all the way down, and that an imported key is passed
/// through byte-for-byte just like one of ours.

const _foreignUri =
    'vless://11111111-2222-3333-4444-555555555555@foreign.example:443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=abc&sid=ff&type=tcp&flow=xtls-rprx-vision#Foreign%20Node';

const _ourUri =
    'vless://99999999-8888-7777-6666-555555555555@nexa.example:443'
    '?encryption=none&security=reality&sni=www.microsoft.com'
    '&pbk=xyz&sid=aa&type=tcp&flow=xtls-rprx-vision#Nexa';

/// Records what the service hands down, without touching a real engine.
class _SpyTunnel implements TunnelManager {
  final _controller = StreamController<TunnelPhase>.broadcast();
  final List<ConnectionSource> started = [];
  int stopCount = 0;

  TunnelPhase _phase = TunnelPhase.idle;

  @override
  TunnelPhase get phase => _phase;

  /// Замер пинга шпиону не нужен: тест проверяет, ЧТО передаётся
  /// в туннель, а не сетевые характеристики.
  @override
  Future<int?> measurePing() async => null;

  @override
  Stream<TunnelPhase> get phases async* {
    yield _phase;
    yield* _controller.stream;
  }

  void _emit(TunnelPhase p) {
    _phase = p;
    _controller.add(p);
  }

  @override
  Future<void> startTunnel(ConnectionSource source, VpnConfig config) async {
    started.add(source);
    _emit(TunnelPhase.handshake);
    _emit(TunnelPhase.connected);
  }

  @override
  Future<void> stopTunnel() async {
    stopCount++;
    _emit(TunnelPhase.idle);
  }

  void dispose() => _controller.close();
}

ConnectionSource _imported() => ConnectionSource.fromImported(
      uri: _foreignUri,
      label: 'Foreign Node',
    );

ConnectionSource _ours() => const ConnectionSource(
      id: 'nexa:key-1',
      label: 'Nexa Key',
      uri: _ourUri,
      origin: ConnectionOrigin.nexa,
    );

({VpnServiceImpl service, _SpyTunnel tunnel}) _build() {
  final tunnel = _SpyTunnel();
  final service = VpnServiceImpl(
    tunnel: tunnel,
    configProvider: () => const VpnConfig(),
    logger: AppLogger(),
  )..init();
  addTearDown(() {
    service.dispose();
    tunnel.dispose();
  });
  return (service: service, tunnel: tunnel);
}

void main() {
  test('an imported key reaches the tunnel with its URI intact', () async {
    final h = _build();
    final key = _imported();

    await h.service.connect(key);

    expect(h.tunnel.started, hasLength(1));
    // The exact link matters: any rewriting would break a stranger's server.
    expect(h.tunnel.started.single.uri, _foreignUri);
    expect(h.tunnel.started.single.origin, ConnectionOrigin.imported);
  });

  test('our own key travels the identical path', () async {
    final h = _build();

    await h.service.connect(_ours());

    expect(h.tunnel.started.single.uri, _ourUri);
    expect(h.tunnel.started.single.origin, ConnectionOrigin.nexa);
  });

  test('the tunnel layer is not told which origin to prefer', () async {
    final imported = _build();
    await imported.service.connect(_imported());

    final ours = _build();
    await ours.service.connect(_ours());

    // Same call shape for both: no branch anywhere below the UI.
    expect(imported.tunnel.started.length, ours.tunnel.started.length);
    expect(imported.service.status, ours.service.status);
  });

  test('connecting reports the active source and reaches connected',
      () async {
    final h = _build();
    final key = _imported();

    await h.service.connect(key);

    expect(h.service.status, VpnStatus.connected);
    expect(h.service.activeSource?.id, key.id);
  });

  test('reconnecting to the same key is a no-op', () async {
    final h = _build();
    final key = _imported();

    await h.service.connect(key);
    await h.service.connect(key);

    expect(h.tunnel.started, hasLength(1));
  });

  test('disconnect tears down and clears the active source', () async {
    final h = _build();
    await h.service.connect(_imported());

    await h.service.disconnect();

    expect(h.tunnel.stopCount, 1);
    expect(h.service.activeSource, isNull);
  });
}
