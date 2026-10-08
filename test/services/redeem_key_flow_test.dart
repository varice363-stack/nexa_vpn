import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morok_vpn/domain/repositories/key_storage.dart';
import 'package:morok_vpn/l10n/app_localizations.dart';
import 'package:morok_vpn/providers/app_providers.dart';
import 'package:morok_vpn/screens/access/key_entry_screen.dart';
import 'package:morok_vpn/services/api/api_client.dart';
import 'package:morok_vpn/services/api/token_storage.dart';
import 'package:morok_vpn/services/identity/identity_store.dart';
import 'package:morok_vpn/widgets/common/glass_button.dart';

/// Критическая регрессия 08.10.2026: покупка доступа.
///
/// Было: покупатель вводил оплаченный код, сервер отвечал «активирован» и
/// отдавал рабочий адрес, но ключ привязывался к случайному идентификатору
/// установки — списка «мои ключи» он не попадал, и подключиться было нечем.
///
/// Тест держит две вещи, которые и делают покупку рабочей:
///  1. в запрос на активацию уходит КОД ВЛАДЕЛЬЦА (MOROK-…), а не случайный id;
///  2. после активации ключ привязывается к аккаунту (POST /provisioning/claim).

const _ownerCode = 'MOROK-AAAA-BBBB-CCCC-DDDD';
const _vless = 'vless://uuid-1@78.17.156.139:443?type=tcp#Morok';

class _MemoryKeyStorage implements KeyStorage {
  final Map<String, String> rows = {'morok_auth_token': 'jwt'};
  @override
  Future<void> write(String key, String value) async => rows[key] = value;
  @override
  Future<String?> read(String key) async => rows[key];
  @override
  Future<void> delete(String key) async => rows.remove(key);
  @override
  Future<bool> has(String key) async => rows.containsKey(key);
}

/// Хранилище кода владельца с заранее известным кодом.
class _FixedIdentityStore extends IdentityStore {
  _FixedIdentityStore()
      : super(
          storage: _MemoryKeyStorage(),
          prefs: _prefs,
        );

  static late SharedPreferences _prefs;

  @override
  Future<String> resolve() async => _ownerCode;
}

Map<String, Object?> _keyJson({bool active = true}) => {
      'id': 'k1',
      'name': 'Morok 30 дней',
      'protocol': 'VLESS',
      'uuid': 'uuid-1',
      'status': active ? 'ACTIVE' : 'REVOKED',
      'createdAt': DateTime.utc(2026, 10, 8).toIso8601String(),
      'expiresAt': DateTime.utc(2026, 11, 8).toIso8601String(),
      'lastUsedAt': null,
      'serverId': null,
      'config': {'format': 'vless', 'uri': _vless, 'qrPayload': _vless},
    };

/// AppPage рисует бесконечную фоновую анимацию, поэтому `pumpAndSettle`
/// на этих экранах не завершается никогда — прокручиваем фиксированное
/// число кадров.
Future<void> frames(WidgetTester tester) async {
  // ApiClient держит паузу 500 мс между запросами, а поток покупки делает их
  // несколько подряд (активация → привязка → список ключей) — если прокрутить
  // меньше, тест увидит экран в середине операции.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Гасит отложенный таймер ограничителя частоты, иначе тест падает на
/// «A Timer is still pending».
Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> redeemBodies;
  late int claimCalls;
  late bool keyVisibleInList;

  /// Экраны приложения, обёрнутые в локализацию. ProviderScope собирается
  /// внутри каждого теста: тип списка подмен в этой версии Riverpod нельзя
  /// назвать явно (имя `Override` занято аннотацией из dart:core).
  Widget app() => const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ru'),
        home: KeyEntryScreen(),
      );

  Future<(ApiClient, SharedPreferences)> makeClient() async {
    final prefs = await SharedPreferences.getInstance();
    _FixedIdentityStore._prefs = prefs;
    final client = ApiClient(
      tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/provisioning/redeem')) {
          redeemBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode(_keyJson()),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/provisioning/claim')) {
          claimCalls++;
          return http.Response(
            jsonEncode(_keyJson()),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/provisioning')) {
          return http.Response(
            jsonEncode(keyVisibleInList ? [_keyJson()] : []),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    return (client, prefs);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    redeemBodies = [];
    claimCalls = 0;
    keyVisibleInList = true;
  });

  testWidgets('оплаченный код активируется кодом владельца и ключ виден',
      (tester) async {
    final (client, prefs) = await makeClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(client),
          identityStoreProvider.overrideWithValue(_FixedIdentityStore()),
        ],
        child: app(),
      ),
    );
    await frames(tester);

    await tester.enterText(find.byType(TextField).first, 'MOROK-XX99-XX99');
    final button = find.widgetWithText(GlassButton, 'Активировать');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await frames(tester);

    expect(redeemBodies, hasLength(1));
    // Главное: уходит код владельца, а не случайный идентификатор установки.
    expect(redeemBodies.first['deviceId'], _ownerCode);
    expect(claimCalls, 1);

    await drain(tester);
  });

  testWidgets('если ключ не появился — честная ошибка, а не «успех»',
      (tester) async {
    keyVisibleInList = false;
    final (client, prefs) = await makeClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(client),
          identityStoreProvider.overrideWithValue(_FixedIdentityStore()),
        ],
        child: app(),
      ),
    );
    await frames(tester);

    await tester.enterText(find.byType(TextField).first, 'MOROK-XX99-XX99');
    final button = find.widgetWithText(GlassButton, 'Активировать');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await frames(tester);

    expect(find.textContaining('ключ не появился'), findsOneWidget);

    await drain(tester);
  });
}
