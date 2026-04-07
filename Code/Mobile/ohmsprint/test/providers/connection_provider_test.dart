import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/connection_state.dart';
import 'package:ohmsprint/providers/connection_provider.dart';
import 'package:ohmsprint/services/http_polling_service.dart';
import 'package:ohmsprint/services/mock_data_service.dart';
import 'package:ohmsprint/services/websocket_service.dart';

void main() {
  test('falls back to HTTP after three websocket failures', () async {
    final websocketService = _QueuedWebSocketService([
      Stream<Map<String, dynamic>>.error(StateError('ws-1')),
      Stream<Map<String, dynamic>>.error(StateError('ws-2')),
      Stream<Map<String, dynamic>>.error(StateError('ws-3')),
    ]);
    final httpService = _PersistentHttpPollingService(_measurementPayload());
    final mockService = MockDataService();
    final notifier = ConnectionNotifier(
      websocketService: websocketService,
      mockDataService: mockService,
      httpPollingServiceFactory: (_) => httpService,
      isDemoMode: () => false,
      reconnectBackoffForAttempt: (_) => Duration.zero,
      websocketRecoveryProbeInterval: const Duration(days: 1),
    );

    addTearDown(() {
      notifier.dispose();
      mockService.dispose();
    });

    unawaited(notifier.connect('192.168.4.1'));

    await _waitFor(
      () =>
          notifier.state.transport == ConnectionTransport.http &&
          notifier.state.isConnected,
    );

    expect(httpService.startCount, greaterThanOrEqualTo(1));
    expect(notifier.state.transport, ConnectionTransport.http);
  });

  test('restores websocket transport after a successful recovery probe',
      () async {
    late final StreamController<Map<String, dynamic>>
        restoredWebSocketController;
    restoredWebSocketController =
        StreamController<Map<String, dynamic>>.broadcast(onListen: () {
      restoredWebSocketController.add(_measurementPayload());
    });
    final websocketService = _QueuedWebSocketService([
      Stream<Map<String, dynamic>>.error(StateError('ws-1')),
      Stream<Map<String, dynamic>>.error(StateError('ws-2')),
      Stream<Map<String, dynamic>>.error(StateError('ws-3')),
      restoredWebSocketController.stream,
    ]);
    final httpService = _PersistentHttpPollingService(_measurementPayload());
    WebSocketService probeFactory() {
      return _QueuedWebSocketService([
        Stream<Map<String, dynamic>>.value(_measurementPayload()),
      ]);
    }

    final mockService = MockDataService();
    final notifier = ConnectionNotifier(
      websocketService: websocketService,
      mockDataService: mockService,
      httpPollingServiceFactory: (_) => httpService,
      isDemoMode: () => false,
      reconnectBackoffForAttempt: (_) => Duration.zero,
      websocketRecoveryProbeInterval: const Duration(milliseconds: 20),
      websocketRecoveryTimeout: const Duration(milliseconds: 50),
      recoveryProbeFactory: probeFactory,
    );

    addTearDown(() {
      notifier.dispose();
      mockService.dispose();
      restoredWebSocketController.close();
    });

    unawaited(notifier.connect('192.168.4.1'));

    await _waitFor(
      () =>
          notifier.state.transport == ConnectionTransport.websocket &&
          notifier.state.isConnected,
    );

    expect(notifier.state.transport, ConnectionTransport.websocket);
    expect(notifier.state.isConnected, isTrue);
  });
}

Map<String, dynamic> _measurementPayload() {
  return {
    'v': 230.0,
    'i': 4.0,
    'p': 920.0,
    'f': 50.0,
    'pf': 0.99,
    't': 12345,
  };
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for predicate.');
}

class _QueuedWebSocketService extends WebSocketService {
  _QueuedWebSocketService(List<Stream<Map<String, dynamic>>> responses)
      : _responses = Queue<Stream<Map<String, dynamic>>>.of(responses);

  final Queue<Stream<Map<String, dynamic>>> _responses;

  @override
  Stream<Map<String, dynamic>> connect(String url) {
    if (_responses.isEmpty) {
      return Stream<Map<String, dynamic>>.error(
        StateError('No queued websocket response for $url'),
      );
    }
    return _responses.removeFirst();
  }

  @override
  void disconnect() {}
}

class _PersistentHttpPollingService extends HttpPollingService {
  _PersistentHttpPollingService(this.payload)
      : _controller = StreamController<Map<String, dynamic>>.broadcast(),
        super('http://device.local');

  final Map<String, dynamic> payload;
  final StreamController<Map<String, dynamic>> _controller;
  int startCount = 0;
  bool _emitted = false;

  @override
  Stream<Map<String, dynamic>> start({
    Duration interval = const Duration(seconds: 1),
  }) {
    startCount += 1;
    if (!_emitted) {
      _emitted = true;
      scheduleMicrotask(() {
        _controller.add(payload);
      });
    }
    return _controller.stream;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
