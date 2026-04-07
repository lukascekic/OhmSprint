enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

enum ConnectionTransport { mock, websocket, http }

class DeviceConnectionState {
  const DeviceConnectionState({
    required this.status,
    this.transport,
    this.ipAddress,
    this.port,
    this.failureCount = 0,
    this.lastError,
  });

  const DeviceConnectionState.disconnected()
      : status = ConnectionStatus.disconnected,
        transport = null,
        ipAddress = null,
        port = null,
        failureCount = 0,
        lastError = null;

  final ConnectionStatus status;
  final ConnectionTransport? transport;
  final String? ipAddress;
  final int? port;
  final int failureCount;
  final String? lastError;

  bool get isConnected => status == ConnectionStatus.connected;

  DeviceConnectionState copyWith({
    ConnectionStatus? status,
    ConnectionTransport? transport,
    String? ipAddress,
    int? port,
    int? failureCount,
    String? lastError,
    bool clearTransport = false,
    bool clearIpAddress = false,
    bool clearPort = false,
    bool clearLastError = false,
  }) {
    return DeviceConnectionState(
      status: status ?? this.status,
      transport: clearTransport ? null : transport ?? this.transport,
      ipAddress: clearIpAddress ? null : ipAddress ?? this.ipAddress,
      port: clearPort ? null : port ?? this.port,
      failureCount: failureCount ?? this.failureCount,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}
