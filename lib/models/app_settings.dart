/// Persisted user settings.
///
/// Состав намеренно короткий: сюда входят только те переключатели, которые
/// во что-то упираются. Протокол, DNS и «kill switch» отсюда удалены, потому
/// что туннель строится исключительно из контракта сервера
/// (XrayTunnelManager.startTunnel не читает VpnConfig ни в одном поле) —
/// кнопки меняли цифру в SharedPreferences и больше ничего.
/// Защита от утечек и автоподключение живут в системной панели Android
/// (см. services/system_vpn_settings.dart), поэтому в настройках это переход,
/// а не переключатель.
class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
  });

  final bool notificationsEnabled;

  AppSettings copyWith({bool? notificationsEnabled}) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
