import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morok_vpn/data/datasources/local_settings_datasource.dart';
import 'package:morok_vpn/data/repositories/session_manager_impl.dart';

/// История подключений — только реальные сессии. Раньше в отладочной сборке
/// при первом запуске писались 14 выдуманных сессий (`_seedDemo`), и экран
/// статистики показывал их как настоящие.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('на пустой установке история пустая, ничего не подставляется', () async {
    final prefs = await SharedPreferences.getInstance();
    final manager = SessionManagerImpl(LocalSettingsDatasource(prefs));

    expect(await manager.getSessions(), isEmpty);
    expect(prefs.getString('history.sessions'), isNull);
  });
}
