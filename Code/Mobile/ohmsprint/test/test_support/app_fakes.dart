import 'dart:async';

import 'package:ohmsprint/core/models/connection_state.dart';
import 'package:ohmsprint/core/models/measurement.dart';
import 'package:ohmsprint/core/models/metric_type.dart';
import 'package:ohmsprint/core/models/power_event.dart';
import 'package:ohmsprint/core/models/settings_model.dart';
import 'package:ohmsprint/providers/connection_provider.dart';
import 'package:ohmsprint/services/http_polling_service.dart';
import 'package:ohmsprint/services/measurement_repository.dart';
import 'package:ohmsprint/services/mock_data_service.dart';
import 'package:ohmsprint/services/notification_service.dart';
import 'package:ohmsprint/services/websocket_service.dart';

class InMemoryMeasurementRepository extends MeasurementRepository {
  InMemoryMeasurementRepository({
    SettingsModel? initialSettings,
    List<Measurement>? initialMeasurements,
  })  : _settings = initialSettings ?? const SettingsModel(),
        _measurements = <Measurement>[
          ...?initialMeasurements,
        ];

  SettingsModel _settings;
  final List<Measurement> _measurements;
  final List<PowerQualityEvent> _events = <PowerQualityEvent>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> saveBatch(List<Measurement> batch) async {
    _measurements.addAll(batch);
    _measurements.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> saveEvent(PowerQualityEvent event) async {
    _events.add(event);
  }

  @override
  List<Measurement> getRange(int fromTimestamp, int toTimestamp) {
    return _measurements
        .where(
          (measurement) =>
              measurement.timestamp >= fromTimestamp &&
              measurement.timestamp <= toTimestamp,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  ({double min, double max, double avg}) getStats(
    MetricType type,
    int fromTimestamp,
    int toTimestamp,
  ) {
    final data = getRange(fromTimestamp, toTimestamp);
    if (data.isEmpty) {
      return (min: 0, max: 0, avg: 0);
    }

    final values =
        data.map((measurement) => measurement.valueFor(type)).toList();
    final minValue =
        values.reduce((left, right) => left < right ? left : right);
    final maxValue =
        values.reduce((left, right) => left > right ? left : right);
    final average = values.reduce((sum, value) => sum + value) / values.length;
    return (min: minValue, max: maxValue, avg: average);
  }

  @override
  Future<void> clearAll() async {
    _measurements.clear();
    _events.clear();
    _settings = const SettingsModel();
  }

  @override
  Future<void> clearMeasurements() async {
    _measurements.clear();
  }

  @override
  SettingsModel loadSettings() => _settings;

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    _settings = settings;
  }

  @override
  Future<void> clearEvents() async {
    _events.clear();
  }
}

class TestConnectionNotifier extends ConnectionNotifier {
  TestConnectionNotifier({
    DeviceConnectionState? initialState,
  }) : super(
          websocketService: _NoopWebSocketService(),
          mockDataService: _NoopMockDataService(),
          httpPollingServiceFactory: (baseUrl) =>
              _NoopHttpPollingService(baseUrl),
          isDemoMode: () => false,
        ) {
    state = initialState ??
        const DeviceConnectionState(
          status: ConnectionStatus.connected,
          transport: ConnectionTransport.mock,
          ipAddress: '192.168.4.1',
        );
  }

  final StreamController<Measurement> _measurementController =
      StreamController<Measurement>.broadcast();
  final StreamController<PowerQualityEvent> _eventController =
      StreamController<PowerQualityEvent>.broadcast();
  bool _didDispose = false;

  @override
  Stream<Measurement> get measurementStream => _measurementController.stream;

  @override
  Stream<PowerQualityEvent> get eventStream => _eventController.stream;

  void setConnectionState(DeviceConnectionState nextState) {
    state = nextState;
  }

  void emitMeasurement(Measurement measurement) {
    _measurementController.add(measurement);
  }

  @override
  Future<void> connect(String ip, {int? port}) async {
    state = DeviceConnectionState(
      status: ConnectionStatus.connected,
      transport: ConnectionTransport.websocket,
      ipAddress: ip,
      port: port,
    );
  }

  @override
  Future<void> disconnect() async {
    state = const DeviceConnectionState.disconnected();
  }

  @override
  void dispose() {
    if (_didDispose) {
      return;
    }
    _didDispose = true;
    unawaited(_measurementController.close());
    unawaited(_eventController.close());
    super.dispose();
  }
}

class SilentNotificationService extends NotificationService {
  SilentNotificationService() : super();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showAlert({
    required String title,
    required String body,
    required int id,
  }) async {}
}

class _NoopWebSocketService extends WebSocketService {
  @override
  Stream<Map<String, dynamic>> connect(String url) {
    return const Stream<Map<String, dynamic>>.empty();
  }

  @override
  void disconnect() {}
}

class _NoopMockDataService extends MockDataService {
  _NoopMockDataService() : super();

  @override
  Stream<Map<String, dynamic>> start({
    Duration interval = const Duration(seconds: 1),
  }) {
    return const Stream<Map<String, dynamic>>.empty();
  }

  @override
  void stop() {}

  @override
  void dispose() {}
}

class _NoopHttpPollingService extends HttpPollingService {
  _NoopHttpPollingService(super.baseUrl);

  @override
  Stream<Map<String, dynamic>> start({
    Duration interval = const Duration(seconds: 1),
  }) {
    return const Stream<Map<String, dynamic>>.empty();
  }

  @override
  Future<void> dispose() async {}
}
