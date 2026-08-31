import 'dart:async';
import 'dart:io';

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

  bool get isVulnerable => isOpen && !isAuthenticated;
}

/// Scans for vulnerable SOCKS5 proxies on the device
///
/// This checks common SOCKS5 ports (1080, 10807, 10808, etc.) and reports
/// if any are open without authentication — a security risk.
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
      // Try to connect with a short timeout
      socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(seconds: 1),
      );

      // Port is open — now check if it requires auth
      // For SOCKS5, we'd need to send a handshake and check response
      // For simplicity, we'll mark it as potentially vulnerable
      // A real implementation would do the full SOCKS5 handshake
      final isAuthenticated = await _checkAuthentication(socket, port);

      return Socks5ScanResult(
        port: port,
        isOpen: true,
        isAuthenticated: isAuthenticated,
        processName: await _getProcessName(port),
      );
    } on SocketException {
      // Port is closed — good!
      return Socks5ScanResult(
        port: port,
        isOpen: false,
        isAuthenticated: true,
      );
    } on TimeoutException {
      // Connection timed out — likely closed or filtered
      return Socks5ScanResult(
        port: port,
        isOpen: false,
        isAuthenticated: true,
      );
    } finally {
      await socket?.close();
    }
  }

  /// Check if SOCKS5 proxy requires authentication
  Future<bool> _checkAuthentication(Socket socket, int port) async {
    // Simplified check — in production, do full SOCKS5 handshake
    // For now, assume if port is open on localhost, it might be vulnerable
    // unless it's our own hardened proxy
    return false; // Assume vulnerable for now
  }

  /// Try to identify which process is listening on the port
  Future<String?> _getProcessName(int port) async {
    // This would require platform-specific code
    // On Android: use `netstat` or `/proc/net/tcp`
    // On iOS: restricted, cannot access this info
    return null;
  }

  /// Count vulnerable ports
  Future<int> countVulnerable() async {
    final results = await scan();
    return results.where((r) => r.isVulnerable).length;
  }
}
