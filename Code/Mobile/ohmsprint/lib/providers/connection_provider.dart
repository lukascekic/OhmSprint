import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/models/connection_state.dart';
import '../core/models/measurement.dart';
import '../core/models/power_event.dart';
import '../services/mock_data_service.dart';
import '../services/websocket_service.dart';
import 'demo_mode_provider.dart';

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.disconnect);
  return service;
});

final mockDataServiceProvider = Provider<MockDataService>((ref) {
  final service = MockDataService();
  ref.onDispose(service.dispose);
  return service;
});

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, DeviceConnectionState>((ref) {
  return ConnectionNotifier(
    websocketService: ref.watch(websocketServiceProvider),
    mockDataService: ref.watch(mockDataServiceProvider),
    isDemoMode: () => ref.read(demoModeProvider),
  );
});

class ConnectionNotifier extends StateNotifier<DeviceConnectionState> {
  ConnectionNotifier({
    required WebSocketService websocketService,
    required MockDataService mockDataService,
    required bool Function() isDemoMode,
  })  : _websocketService = websocketService,
        _mockDataService = mockDataService,
        _isDemoMode = isDemoMode,
        super(const DeviceConnectionState.disconnected());

  final WebSocketService _websocketService;
  final MockDataService _mockDataService;
  final bool Function() _isDemoMode;
  final StreamController<Measurement> _measurementController =
      StreamController<Measurement>.broadcast();
  final StreamController<PowerQualityEvent> _eventController =
      StreamController<PowerQualityEvent>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _sourceSubscription;
  Timer? _reconnectTimer;
  bool _disconnectRequested = false;

  Stream<Measurement> get measurementStream => _measurementController.stream;
  Stream<PowerQualityEvent> get eventStream => _eventController.stream;

  Future<void> connect(String ip) async {
    _disconnectRequested = false;
    _reconnectTimer?.cancel();
    await _sourceSubscription?.cancel();
    _websocketService.disconnect();
    _mockDataService.stop();

    if (_isDemoMode()) {
      state = DeviceConnectionState(
        status: ConnectionStatus.connecting,
        transport: ConnectionTransport.mock,
        ipAddress: ip,
      );
      _listenToSource(
        _mockDataService.start(),
        ip: ip,
        transport: ConnectionTransport.mock,
      );
      return;
    }

    state = DeviceConnectionState(
      status: ConnectionStatus.connecting,
      transport: ConnectionTransport.websocket,
      ipAddress: ip,
    );
    _connectWebSocket(ip, failureCount: 0);
  }

  Future<void> disconnect() async {
    _disconnectRequested = true;
    _reconnectTimer?.cancel();
    await _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _websocketService.disconnect();
    _mockDataService.stop();
    state = const DeviceConnectionState.disconnected();
  }

  void _connectWebSocket(String ip, {required int failureCount}) {
    try {
      final stream = _websocketService.connect(_buildWebSocketUrl(ip));
      _listenToSource(
        stream,
        ip: ip,
        transport: ConnectionTransport.websocket,
        failureCount: failureCount,
      );
    } catch (error) {
      _scheduleReconnect(ip, failureCount + 1, error.toString());
    }
  }

  void _listenToSource(
    Stream<Map<String, dynamic>> source, {
    required String ip,
    required ConnectionTransport transport,
    int failureCount = 0,
  }) {
    _sourceSubscription = source.listen(
      (payload) {
        state = state.copyWith(
          status: ConnectionStatus.connected,
          transport: transport,
          ipAddress: ip,
          failureCount: 0,
          clearLastError: true,
        );

        try {
          if (payload.containsKey('ev')) {
            _eventController.add(PowerQualityEvent.fromJson(payload));
          } else {
            _measurementController.add(Measurement.fromJson(payload));
          }
        } catch (error, stackTrace) {
          // Drop malformed payloads to keep the stream alive.
          debugPrint('Malformed payload dropped: $error\n$stackTrace');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_disconnectRequested) {
          return;
        }
        _scheduleReconnect(ip, state.failureCount + 1, error.toString());
      },
      onDone: () {
        if (_disconnectRequested) {
          return;
        }
        _scheduleReconnect(ip, state.failureCount + 1, 'Connection closed');
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect(String ip, int failureCount, String error) {
    _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _websocketService.disconnect();

    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      transport: ConnectionTransport.websocket,
      ipAddress: ip,
      failureCount: failureCount,
      lastError: error,
    );

    final delay = _backoffForAttempt(failureCount);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disconnectRequested) {
        return;
      }
      _connectWebSocket(ip, failureCount: failureCount);
    });
  }

  Duration _backoffForAttempt(int attempt) {
    if (attempt <= 1) {
      return AppConstants.reconnectDelayInitial;
    }
    if (attempt == 2) {
      return AppConstants.reconnectDelaySecondary;
    }
    if (attempt == 3) {
      return AppConstants.reconnectDelayTertiary;
    }
    return AppConstants.reconnectDelayMax;
  }

  String _buildWebSocketUrl(String ip) {
    if (ip.startsWith('ws://') || ip.startsWith('wss://')) {
      return ip;
    }
    return 'ws://$ip/ws';
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sourceSubscription?.cancel();
    _websocketService.disconnect();
    _mockDataService.stop();
    _measurementController.close();
    _eventController.close();
    super.dispose();
  }
}
