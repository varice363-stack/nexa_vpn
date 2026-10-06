import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Точка входа в системную панель «Постоянный VPN» (Android 12+).
///
/// Приложение не может включить блокировку трафика без туннеля самому — это
/// право только у ОС. Здесь только честный запрос: «открой панель, где это
/// включается», и ответ, доступно ли это на данном Android.
class SystemVpnSettings {
  const SystemVpnSettings();

  static const MethodChannel _channel =
      MethodChannel('com.morokvpn.app/vpn_settings');

  /// Есть ли у ОС панель, где включается «Block connections without VPN».
  /// false на Android < 12 и на десктопе/эмуляторе каналов.
  Future<bool> isSystemPanelAvailable() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isSystemPanelAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Открыть системную панель VPN. true — если экран реально показался.
  Future<bool> openSystemPanel() async {
    try {
      return await _channel.invokeMethod<bool>('openSystemPanel') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Единственный экземпляр — канал stateless, пересоздавать нечего.
const systemVpnSettings = SystemVpnSettings();
