import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/models/connection_state.dart';
import '../core/models/measurement.dart';
import '../core/models/power_event.dart';
import '../services/http_polling_service.dart';
import '../services/mock_data_service.dart';
import '../services/websocket_service.dart';
import 'demo_mode_provider.dart';

typedef HttpPollingServiceFactory = HttpPollingService Function(String baseUrl);
typedef WebSocketServiceFactory = WebSocketService Function();

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

final httpPollingServiceFactoryProvider = Provider<HttpPollingServiceFactory>((
  ref,
) {
  return (baseUrl) => HttpPollingService(baseUrl);
});

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, DeviceConnectionState>((ref) {
  return ConnectionNotifier(
    websocketService: ref.watch(websocketServiceProvider),
    mockDataService: ref.watch(mockDataServiceProvider),
    httpPollingServiceFactory: ref.watch(httpPollingServiceFactoryProvider),
    isDemoMode: () => ref.read(demoModeProvider),
  );
});

class ConnectionNotifier extends StateNotifier<DeviceConnectionState> {
  ConnectionNotifier({
    required WebSocketService websocketService,
    required MockDataService mockDataService,
    required HttpPollingServiceFactory httpPollingServiceFactory,
    required bool Function() isDemoMode,
    Duration Function(int attempt)? reconnectBackoffForAttempt,
    Duration websocketRecoveryProbeInterval = const Duration(seconds: 8),
    Duration websocketRecoveryTimeout = const Duration(seconds: 3),
    WebSocketServiceFactory? recoveryProbeFactory,
  })  : _websocketService = websocketService,
        _mockDataService = mockDataService,
        _httpPollingServiceFactory = httpPollingServiceFactory,
        _isDemoMode = isDemoMode,
        _reconnectBackoffForAttempt =
            reconnectBackoffForAttempt ?? _defaultBackoffForAttempt,
        _websocketRecoveryProbeInterval = websocketRecoveryProbeInterval,
        _websocketRecoveryTimeout = websocketRecoveryTimeout,
        _recoveryProbeFactory = recoveryProbeFactory ?? WebSocketService.new,
        super(const DeviceConnectionState.disconnected());

  final WebSocketService _websocketService;
  final MockDataService _mockDataService;
  final HttpPollingServiceFactory _httpPollingServiceFactory;
  final bool Function() _isDemoMode;
  final Duration Function(int attempt) _reconnectBackoffForAttempt;
  final Duration _websocketRecoveryProbeInterval;
  final Duration _websocketRecoveryTimeout;
  final WebSocketServiceFactory _recoveryProbeFactory;
  final StreamController<Measurement> _measurementController =
      StreamController<Measurement>.broadcast();
  final StreamController<PowerQualityEvent> _eventController =
      StreamController<PowerQualityEvent>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _sourceSubscription;
  Timer? _reconnectTimer;
  Timer? _websocketRecoveryTimer;
  HttpPollingService? _httpPollingService;
  bool _disconnectRequested = false;
  bool _isRecoveryProbeActive = false;
  int _connectionGeneration = 0;
  int _httpFallbackRestartCount = 0;

  static const int _maxHttpFallbackRestarts = 5;

  static Duration _defaultBackoffForAttempt(int attempt) {
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

  Stream<Measurement> get measurementStream => _measurementController.stream;
  Stream<PowerQualityEvent> get eventStream => _eventController.stream;

  Future<void> connect(String ip, {int? port}) async {
    _connectionGeneration += 1;
    _httpFallbackRestartCount = 0;
    _disconnectRequested = false;
    _reconnectTimer?.cancel();
    _websocketRecoveryTimer?.cancel();
    await _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _websocketService.disconnect();
    _mockDataService.stop();
    await _disposeHttpPollingService();

    if (_isDemoMode()) {
      state = DeviceConnectionState(
        status: ConnectionStatus.connecting,
        transport: ConnectionTransport.mock,
        ipAddress: ip,
        port: port,
      );
      _listenToSource(
        _mockDataService.start(),
        ip: ip,
        port: port,
        transport: ConnectionTransport.mock,
      );
      return;
    }

    state = DeviceConnectionState(
      status: ConnectionStatus.connecting,
      transport: ConnectionTransport.websocket,
      ipAddress: ip,
      port: port,
    );
    _connectWebSocket(ip, port: port, failureCount: 0);
  }

  Future<void> disconnect() async {
    _connectionGeneration += 1;
    _disconnectRequested = true;
    _reconnectTimer?.cancel();
    _websocketRecoveryTimer?.cancel();
    await _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _websocketService.disconnect();
    _mockDataService.stop();
    await _disposeHttpPollingService();
    state = const DeviceConnectionState.disconnected();
  }

  void _connectWebSocket(
    String ip, {
    int? port,
    required int failureCount,
  }) {
    try {
      final stream =
          _websocketService.connect(_buildWebSocketUrl(ip, port: port));
      _listenToSource(
        stream,
        ip: ip,
        port: port,
        transport: ConnectionTransport.websocket,
        failureCount: failureCount,
      );
    } catch (error) {
      _scheduleReconnect(
        ip,
        port: port,
        failureCount: failureCount + 1,
        error: error.toString(),
      );
    }
  }

  void _listenToSource(
    Stream<Map<String, dynamic>> source, {
    required String ip,
    int? port,
    required ConnectionTransport transport,
    int failureCount = 0,
  }) {
    late final StreamSubscription<Map<String, dynamic>> subscription;
    subscription = source.listen(
      (payload) {
        if (!identical(_sourceSubscription, subscription)) {
          return;
        }
        state = state.copyWith(
          status: ConnectionStatus.connected,
          transport: transport,
          ipAddress: ip,
          port: port,
          failureCount: 0,
          clearLastError: true,
        );
        _httpFallbackRestartCount = 0;

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
        if (_disconnectRequested ||
            !identical(_sourceSubscription, subscription)) {
          return;
        }
        if (transport == ConnectionTransport.websocket) {
          _scheduleReconnect(
            ip,
            port: port,
            failureCount: state.failureCount + 1,
            error: error.toString(),
          );
        } else if (transport == ConnectionTransport.http) {
          unawaited(
            _handleHttpTransportFailure(
              ip,
              port: port,
              error: error.toString(),
            ),
          );
        } else if (transport == ConnectionTransport.mock) {
          _scheduleMockReconnect(ip, port: port, error: error.toString());
        }
      },
      onDone: () {
        if (_disconnectRequested ||
            !identical(_sourceSubscription, subscription)) {
          return;
        }
        if (transport == ConnectionTransport.websocket) {
          _scheduleReconnect(
            ip,
            port: port,
            failureCount: state.failureCount + 1,
            error: 'Connection closed',
          );
        } else if (transport == ConnectionTransport.http) {
          unawaited(
            _handleHttpTransportFailure(
              ip,
              port: port,
              error: 'HTTP polling stopped',
            ),
          );
        } else if (transport == ConnectionTransport.mock) {
          _scheduleMockReconnect(ip, port: port, error: 'Mock stream stopped');
        }
      },
      cancelOnError: false,
    );
    _sourceSubscription = subscription;
  }

  void _scheduleReconnect(
    String ip, {
    int? port,
    required int failureCount,
    required String error,
  }) {
    _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _websocketService.disconnect();

    if (failureCount >= 3) {
      _startHttpFallback(
        ip,
        port: port,
        failureCount: failureCount,
        error: error,
      );
      return;
    }

    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      transport: ConnectionTransport.websocket,
      ipAddress: ip,
      port: port,
      failureCount: failureCount,
      lastError: error,
    );

    final delay = _reconnectBackoffForAttempt(failureCount);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disconnectRequested) {
        return;
      }
      _connectWebSocket(ip, port: port, failureCount: failureCount);
    });
  }

  void _startHttpFallback(
    String ip, {
    int? port,
    required int failureCount,
    required String error,
  }) {
    debugPrint(
      'WebSocket failed $failureCount times; switching to HTTP polling fallback.',
    );

    _reconnectTimer?.cancel();
    _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _websocketService.disconnect();
    unawaited(_disposeHttpPollingService());

    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      transport: ConnectionTransport.http,
      ipAddress: ip,
      port: port,
      failureCount: failureCount,
      lastError: 'WebSocket unavailable, polling over HTTP. Last error: $error',
    );

    _httpPollingService =
        _httpPollingServiceFactory(_buildHttpBaseUrl(ip, port: port));
    _listenToSource(
      _httpPollingService!.start(),
      ip: ip,
      port: port,
      transport: ConnectionTransport.http,
      failureCount: failureCount,
    );
    _scheduleWebSocketRecoveryProbe(ip, port: port);
  }

  void _scheduleMockReconnect(
    String ip, {
    int? port,
    required String error,
  }) {
    _reconnectTimer?.cancel();
    final failureCount = state.failureCount + 1;
    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      transport: ConnectionTransport.mock,
      ipAddress: ip,
      port: port,
      failureCount: failureCount,
      lastError: error,
    );
    _reconnectTimer = Timer(_reconnectBackoffForAttempt(failureCount), () {
      if (_disconnectRequested || !_isDemoMode()) {
        return;
      }
      unawaited(connect(ip, port: port));
    });
  }

  Future<void> _handleHttpTransportFailure(
    String ip, {
    int? port,
    required String error,
  }) async {
    if (_disconnectRequested || state.transport != ConnectionTransport.http) {
      return;
    }

    debugPrint('HTTP polling degraded: $error');
    await _sourceSubscription?.cancel();
    _sourceSubscription = null;
    await _disposeHttpPollingService();

    _httpFallbackRestartCount += 1;
    if (_httpFallbackRestartCount > _maxHttpFallbackRestarts) {
      _reconnectTimer?.cancel();
      _websocketRecoveryTimer?.cancel();
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        transport: ConnectionTransport.http,
        ipAddress: ip,
        port: port,
        lastError:
            'HTTP fallback exhausted after $_maxHttpFallbackRestarts retries. Please retry manually.',
      );
      return;
    }

    final restartDelaySeconds = (1 << _httpFallbackRestartCount).clamp(2, 30);

    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      transport: ConnectionTransport.http,
      ipAddress: ip,
      port: port,
      lastError:
          'HTTP polling interrupted. Retrying fallback in ${restartDelaySeconds}s. Last error: $error',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: restartDelaySeconds), () {
      if (_disconnectRequested || state.transport != ConnectionTransport.http) {
        return;
      }
      _startHttpFallback(
        ip,
        port: port,
        failureCount: state.failureCount,
        error: error,
      );
    });
  }

  void _scheduleWebSocketRecoveryProbe(String ip, {int? port}) {
    _websocketRecoveryTimer?.cancel();
    _websocketRecoveryTimer = Timer.periodic(
      _websocketRecoveryProbeInterval,
      (_) {
        unawaited(_attemptWebSocketRecovery(ip, port: port));
      },
    );
  }

  Future<void> _attemptWebSocketRecovery(String ip, {int? port}) async {
    if (_disconnectRequested ||
        _isRecoveryProbeActive ||
        state.transport != ConnectionTransport.http) {
      return;
    }

    final generation = _connectionGeneration;
    _isRecoveryProbeActive = true;
    final probe = _recoveryProbeFactory();
    try {
      await probe
          .connect(_buildWebSocketUrl(ip, port: port))
          .first
          .timeout(_websocketRecoveryTimeout);
      if (_disconnectRequested ||
          _connectionGeneration != generation ||
          state.transport != ConnectionTransport.http ||
          state.ipAddress != ip ||
          state.port != port) {
        probe.disconnect();
        return;
      }

      debugPrint('WebSocket transport recovered; switching back from HTTP.');
      probe.disconnect();

      await _sourceSubscription?.cancel();
      _sourceSubscription = null;
      await _disposeHttpPollingService();

      state = state.copyWith(
        status: ConnectionStatus.reconnecting,
        transport: ConnectionTransport.websocket,
        ipAddress: ip,
        port: port,
        failureCount: 0,
        lastError: 'WebSocket recovered. Restoring live stream.',
      );
      _connectWebSocket(ip, port: port, failureCount: 0);
    } catch (_) {
      probe.disconnect();
    } finally {
      _isRecoveryProbeActive = false;
    }
  }

  String _buildWebSocketUrl(String ip, {int? port}) {
    if (ip.startsWith('ws://') || ip.startsWith('wss://')) {
      return ip;
    }
    final portSuffix = port == null ? '' : ':$port';
    return 'ws://$ip$portSuffix/ws';
  }

  String _buildHttpBaseUrl(String ip, {int? port}) {
    final uri = Uri.tryParse(ip);
    if (uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'ws' || uri.scheme == 'wss')) {
      final scheme = uri.scheme == 'wss' ? 'https' : 'http';
      final effectivePort = uri.hasPort ? uri.port : port;
      final portSuffix = effectivePort == null ? '' : ':$effectivePort';
      return '$scheme://${uri.host}$portSuffix';
    }

    final sanitizedIp = ip.split('/').first.trim();
    final portSuffix = port == null ? '' : ':$port';
    return 'http://$sanitizedIp$portSuffix';
  }

  Future<void> _disposeHttpPollingService() async {
    _websocketRecoveryTimer?.cancel();
    final service = _httpPollingService;
    _httpPollingService = null;
    await service?.dispose();
  }

  @override
  void dispose() {
    _connectionGeneration += 1;
    _reconnectTimer?.cancel();
    _websocketRecoveryTimer?.cancel();
    _sourceSubscription?.cancel();
    _websocketService.disconnect();
    _mockDataService.stop();
    unawaited(_disposeHttpPollingService().catchError((Object error) {
      debugPrint('Failed to dispose HTTP polling service: $error');
    }));
    _measurementController.close();
    _eventController.close();
    super.dispose();
  }
}
