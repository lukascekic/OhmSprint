import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ohmsprint/core/models/metric_type.dart';
import 'package:ohmsprint/providers/connection_provider.dart';
import 'package:ohmsprint/providers/demo_mode_provider.dart';
import 'package:ohmsprint/providers/measurement_provider.dart';
import 'package:ohmsprint/providers/power_events_provider.dart';
import 'package:ohmsprint/providers/stats_provider.dart';
import 'package:ohmsprint/services/measurement_repository.dart';
import 'package:ohmsprint/services/mock_data_service.dart';
import 'package:ohmsprint/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full data pipeline', () {
    late ProviderContainer container;
    late MeasurementRepository repo;
    late Directory hiveDir;
    late _IntegrationMockDataService mockService;
    late _SilentNotificationService notificationService;

    setUp(() async {
      hiveDir = await Directory.systemTemp.createTemp('ohmsprint_data_flow_');
      Hive.init(hiveDir.path);

      repo = MeasurementRepository();
      await repo.init();
      mockService = _IntegrationMockDataService();
      notificationService = _SilentNotificationService();

      container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith((ref) => true),
          measurementRepositoryProvider.overrideWithValue(repo),
          mockDataServiceProvider.overrideWithValue(mockService),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
      );

      _primeDataPipeline(container);
    });

    tearDown(() async {
      container.dispose();
      mockService.dispose();
      await Future<void>.delayed(Duration.zero);
      await Hive.close();
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }
    });

    test('mock data flows through to latest measurement', () async {
      unawaited(container.read(connectionProvider.notifier).connect('mock'));

      await _waitUntil(
        () => container.read(latestMeasurementProvider) != null,
      );

      final latest = container.read(latestMeasurementProvider);
      expect(latest, isNotNull);
      expect(latest!.voltage, inInclusiveRange(200.0, 260.0));
      expect(latest.frequency, inInclusiveRange(49.0, 51.0));
    });

    test('measurements accumulate in history buffer and persist to Hive',
        () async {
      unawaited(container.read(connectionProvider.notifier).connect('mock'));

      await _waitUntil(
        () => container.read(measurementHistoryProvider).length >= 3,
      );

      final history = container.read(measurementHistoryProvider);
      expect(history.length, greaterThanOrEqualTo(3));

      await container.read(measurementHistoryProvider.notifier).flushPending();
      final persisted = repo.getRange(0, DateTime.now().millisecondsSinceEpoch);
      expect(persisted.length, greaterThanOrEqualTo(3));
    });

    test('events are captured from the mock stream', () async {
      unawaited(container.read(connectionProvider.notifier).connect('mock'));

      await _waitUntil(
        () => container
            .read(powerEventsProvider)
            .any((event) => event.description.contains('Voltage sag')),
      );

      final events = container.read(powerEventsProvider);
      expect(events, isNotEmpty);
      expect(
        events.any((event) => event.description.contains('Voltage sag')),
        isTrue,
      );
    });

    test('pending measurements flush on app lifecycle pause', () async {
      unawaited(container.read(connectionProvider.notifier).connect('mock'));

      await _waitUntil(
        () => container.read(measurementHistoryProvider).length >= 2,
      );

      container
          .read(measurementHistoryProvider.notifier)
          .didChangeAppLifecycleState(AppLifecycleState.paused);

      await _waitUntil(
        () =>
            repo.getRange(0, DateTime.now().millisecondsSinceEpoch).isNotEmpty,
      );

      final persisted = repo.getRange(0, DateTime.now().millisecondsSinceEpoch);
      expect(persisted, isNotEmpty);
    });

    test('stats compute correctly from accumulated history', () async {
      unawaited(container.read(connectionProvider.notifier).connect('mock'));

      await _waitUntil(
        () => container.read(measurementHistoryProvider).length >= 4,
      );

      final history = container.read(measurementHistoryProvider);
      final voltages =
          history.map((measurement) => measurement.voltage).toList();
      final stats = container.read(
        statsProvider((type: MetricType.voltage, secondsBack: 60)),
      );

      expect(stats.min, lessThanOrEqualTo(stats.avg));
      expect(stats.avg, lessThanOrEqualTo(stats.max));
      expect(
          stats.min, closeTo(voltages.reduce((a, b) => a < b ? a : b), 0.0001));
      expect(
          stats.max, closeTo(voltages.reduce((a, b) => a > b ? a : b), 0.0001));
    });
  });
}

void _primeDataPipeline(ProviderContainer container) {
  container.read(connectionProvider.notifier);
  container.read(measurementHistoryProvider.notifier);
  container.read(powerEventsProvider.notifier);
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      if (predicate()) {
        return;
      }
    } catch (_) {
      // The container may be tearing down after an earlier failure.
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for pipeline condition.');
}

class _IntegrationMockDataService extends MockDataService {
  _IntegrationMockDataService();

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _timer;
  int _tick = 0;
  bool _disposed = false;

  @override
  Stream<Map<String, dynamic>> start({
    Duration interval = const Duration(seconds: 1),
  }) {
    if (_disposed) {
      throw StateError('Mock test service has been disposed');
    }

    if (_timer != null) {
      return _controller.stream;
    }

    scheduleMicrotask(_emitMeasurement);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _emitMeasurement();
      if (_tick == 2) {
        _controller.add({
          'ev': 'sag',
          'v': 218.3,
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });

    return _controller.stream;
  }

  void _emitMeasurement() {
    _tick += 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _controller.add({
      'v': 228.0 + _tick,
      'i': 4.0 + (_tick * 0.1),
      'in': 3.8 + (_tick * 0.1),
      'p': 900.0 + (_tick * 8),
      'q': 42.0 + _tick,
      's': 940.0 + (_tick * 9),
      'f': 49.9 + (_tick * 0.01),
      'pf': 0.95,
      't': timestamp,
      'ei': _tick * 0.05,
      'ee': 0.0,
    });
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    _controller.close();
    super.dispose();
  }
}

class _SilentNotificationService extends NotificationService {
  _SilentNotificationService() : super();

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
