/// Device information for multi-device support.
///
/// Tracks connected devices per user account. Allows users to manage
/// their devices and see which ones are currently active.
///
/// Limits:
/// - Free tier: 1 device
/// - Standard tier: 3 devices
/// - Premium tier: 5 devices
class DeviceInfo {
  /// Unique device identifier (generated from device fingerprint).
  final String deviceId;

  /// Human-readable device name (e.g., "iPhone 13", "Pixel 6").
  final String deviceName;

  /// Operating system (e.g., "Android 13", "iOS 16").
  final String os;

  /// Last connection timestamp.
  final DateTime lastConnectedAt;

  /// Whether the device is currently connected.
  final bool isConnected;

  /// IP address of the last connection (for user reference).
  final String? lastIpAddress;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.os,
    required this.lastConnectedAt,
    this.isConnected = false,
    this.lastIpAddress,
  });

  /// Create from JSON.
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      os: json['os'] as String,
      lastConnectedAt: DateTime.parse(json['lastConnectedAt'] as String),
      isConnected: json['isConnected'] as bool? ?? false,
      lastIpAddress: json['lastIpAddress'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'os': os,
      'lastConnectedAt': lastConnectedAt.toIso8601String(),
      'isConnected': isConnected,
      'lastIpAddress': lastIpAddress,
    };
  }

  /// Create a copy with updated fields.
  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    String? os,
    DateTime? lastConnectedAt,
    bool? isConnected,
    String? lastIpAddress,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      os: os ?? this.os,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      isConnected: isConnected ?? this.isConnected,
      lastIpAddress: lastIpAddress ?? this.lastIpAddress,
    );
  }
}
