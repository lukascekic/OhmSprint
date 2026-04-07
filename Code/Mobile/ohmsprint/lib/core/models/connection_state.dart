enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

enum ConnectionTransport { mock, websocket }

class DeviceConnectionState {
  const DeviceConnectionState({
    required this.status,
    this.transport,
    this.ipAddress,
    this.failureCount = 0,
    this.lastError,
  });

  const DeviceConnectionState.disconnected()
      : status = ConnectionStatus.disconnected,
        transport = null,
        ipAddress = null,
        failureCount = 0,
        lastError = null;

  final ConnectionStatus status;
  final ConnectionTransport? transport;
  final String? ipAddress;
  final int failureCount;
  final String? lastError;

  bool get isConnected => status == ConnectionStatus.connected;

  DeviceConnectionState copyWith({
    ConnectionStatus? status,
    ConnectionTransport? transport,
    String? ipAddress,
    int? failureCount,
    String? lastError,
    bool clearTransport = false,
    bool clearIpAddress = false,
    bool clearLastError = false,
  }) {
    return DeviceConnectionState(
      status: status ?? this.status,
      transport: clearTransport ? null : transport ?? this.transport,
      ipAddress: clearIpAddress ? null : ipAddress ?? this.ipAddress,
      failureCount: failureCount ?? this.failureCount,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}
