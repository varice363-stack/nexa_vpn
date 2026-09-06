import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Result of a SOCKS5 port scan
class Socks5ScanResult {
  const Socks5ScanResult({
    required this.port,
    required this.isOpen,
    required this.isAuthenticated,
    this.processName,
  });

  final int port;
  final bool isOpen;
  final bool isAuthenticated;
  final String? processName;

  /// Уязвим = порт открыт И не требует аутентификации.
  bool get isVulnerable => isOpen && !isAuthenticated;
}

/// Сканирует порты устройства на предмет уязвимых SOCKS5 прокси.
///
/// Проверяет распространённые порты (1080, 10807, 10808 и др.) и определяет:
/// - открыт ли порт
/// - требует ли он аутентификацию (безопасно) или нет (уязвимо)
///
/// Использует настоящий SOCKS5 handshake: отправляет приветствие без авторизации
/// и анализирует ответ сервера.
class Socks5Scanner {
  const Socks5Scanner();

  /// Common SOCKS5 ports used by VPN apps
  static const List<int> commonPorts = [
    1080,  // Standard SOCKS5
    10807, // Xray/V2Ray default
    10808, // V2Ray alternative
    10809, // Sing-box
    20170, // Clash
    20171, // Clash alternative
    7890,  // Clash default
    7891,  // Clash alternative
  ];

  /// Scan for vulnerable SOCKS5 proxies
  Future<List<Socks5ScanResult>> scan() async {
    final results = <Socks5ScanResult>[];

    for (final port in commonPorts) {
      final result = await _checkPort(port);
      results.add(result);
    }

    return results;
  }

  /// Check if a specific port has an open SOCKS5 proxy
  Future<Socks5ScanResult> _checkPort(int port) async {
    Socket? socket;
    try {
      // Подключаемся с коротким таймаутом
      socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(seconds: 1),
      ).timeout(const Duration(seconds: 1));

      // Порт открыт — делаем настоящий SOCKS5 handshake для проверки авторизации
      final isAuthenticated = await _checkAuthentication(socket);

      await socket.close();

      return Socks5ScanResult(
        port: port,
        isOpen: true,
        isAuthenticated: isAuthenticated,
        processName: await _getProcessName(port),
      );
    } on SocketException {
      // Порт закрыт — безопасно!
      return Socks5ScanResult(
        port: port,
        isOpen: false,
        isAuthenticated: true, // закрытый порт = нет риска
      );
    } on TimeoutException {
      // Таймаут — скорее всего закрыт или фильтруется
      return Socks5ScanResult(
        port: port,
        isOpen: false,
        isAuthenticated: true,
      );
    } catch (e) {
      // Любая другая ошибка — считаем порт безопасным
      await socket?.close();
      return Socks5ScanResult(
        port: port,
        isOpen: false,
        isAuthenticated: true,
      );
    }
  }

  /// Настоящий SOCKS5 handshake для проверки аутентификации.
  ///
  /// Протокол SOCKS5 (RFC 1928):
  /// 1. Клиент отправляет: [0x05, N_methods, method_1, method_2, ...]
  ///    где method 0x00 = No Auth, 0x02 = Username/Password
  /// 2. Сервер отвечает: [0x05, selected_method]
  ///    где 0x00 = No Auth (УЯЗВИМО!), 0x02 = Username/Password (безопасно),
  ///         0xFF = No acceptable methods (не SOCKS5 или не принимает)
  Future<bool> _checkAuthentication(Socket socket) async {
    try {
      // Отправляем SOCKS5 greeting: версион 5, предлагаем NO AUTH (0x00)
      // Если сервер примет NO AUTH (ответит 0x05 0x00) — он уязвим
      // Если потребует другой метод — он защищён
      final greeting = [0x05, 0x01, 0x00]; // VER=5, NMETHODS=1, METHODS=[NO AUTH]
      socket.add(greeting);
      await socket.flush();

      // Ждём ответ сервера с таймаутом
      final response = await socket.first.timeout(
        const Duration(seconds: 1),
        onTimeout: () => Uint8List(0),
      );

      if (response.length < 2) {
        // Не получили нормальный SOCKS5 ответ
        // Это может быть не SOCKS5 прокси вообще — считаем безопасным
        return true;
      }

      final selectedMethod = response[1];

      switch (selectedMethod) {
        case 0x00:
          // Сервер принял NO AUTH — порт уязвим!
          return false;
        case 0x02:
          // Сервер требует Username/Password — защищён
          return true;
        case 0xFF:
          // Нет приемлемых методов — не SOCKS5 или закрыт для нас
          return true;
        default:
          // Другие методы (GSSAPI и т.д.) — есть какая-то аутентификация
          return true;
      }
    } catch (e) {
      // Ошибка при handshake — считаем безопасным (не можем подтвердить уязвимость)
      return true;
    }
  }

  /// Try to identify which process is listening on the port
  Future<String?> _getProcessName(int port) async {
    // Android: можно использовать Process.run('netstat', ['-tlnp'])
    // но это требует root или специальных разрешений.
    // Для обычного пользователя — просто идентифицируем по номеру порта.
    switch (port) {
      case 1080:
        return 'SOCKS5 стандартный';
      case 10807:
        return 'Xray / V2Ray';
      case 10808:
        return 'V2Ray (альт.)';
      case 10809:
        return 'Sing-box';
      case 7890:
      case 7891:
        return 'Clash';
      case 20170:
      case 20171:
        return 'Clash (альт.)';
      default:
        return null;
    }
  }

  /// Count vulnerable ports
  Future<int> countVulnerable() async {
    final results = await scan();
    return results.where((r) => r.isVulnerable).length;
  }
}
