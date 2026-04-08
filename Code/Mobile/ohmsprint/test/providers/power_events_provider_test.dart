import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/power_event.dart';
import 'package:ohmsprint/core/models/settings_model.dart';
import 'package:ohmsprint/providers/power_events_provider.dart';
import 'package:ohmsprint/services/measurement_repository.dart';
import 'package:ohmsprint/services/notification_service.dart';

void main() {
  test('sends a notification when alerts are enabled', () async {
    final eventController = StreamController<PowerQualityEvent>.broadcast();
    final repository = _FakeMeasurementRepository();
    final notificationService = _FakeNotificationService();
    final notifier = PowerEventsNotifier(
      repository: repository,
      eventStream: eventController.stream,
      currentSettings: () => const SettingsModel(notificationsEnabled: true),
      notificationService: notificationService,
    );

    addTearDown(() async {
      await eventController.close();
      notifier.dispose();
    });

    eventController.add(
      PowerQualityEvent.fromJson({'ev': 'sag', 'v': 218.3, 'ts': 100}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notificationService.alerts, hasLength(1));
    expect(notificationService.alerts.single.title, 'Voltage Sag');
    expect(notificationService.alerts.single.body, contains('218.3V'));
  });

  test('does not send notifications when alerts are disabled', () async {
    final eventController = StreamController<PowerQualityEvent>.broadcast();
    final notificationService = _FakeNotificationService();
    final notifier = PowerEventsNotifier(
      repository: _FakeMeasurementRepository(),
      eventStream: eventController.stream,
      currentSettings: () => const SettingsModel(notificationsEnabled: false),
      notificationService: notificationService,
    );

    addTearDown(() async {
      await eventController.close();
      notifier.dispose();
    });

    eventController.add(
      PowerQualityEvent.fromJson({'ev': 'freq', 'f': 49.42, 'ts': 100}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notificationService.alerts, isEmpty);
  });

  test('debounces repeated alerts of the same type for sixty seconds',
      () async {
    final eventController = StreamController<PowerQualityEvent>.broadcast();
    final notificationService = _FakeNotificationService();
    var clock = DateTime(2026, 4, 8, 12, 0, 0);
    final notifier = PowerEventsNotifier(
      repository: _FakeMeasurementRepository(),
      eventStream: eventController.stream,
      currentSettings: () => const SettingsModel(notificationsEnabled: true),
      notificationService: notificationService,
      now: () => clock,
    );

    addTearDown(() async {
      await eventController.close();
      notifier.dispose();
    });

    eventController.add(
      PowerQualityEvent.fromJson({'ev': 'lpf', 'pf': 0.72, 'ts': 100}),
    );
    await Future<void>.delayed(Duration.zero);

    clock = clock.add(const Duration(seconds: 30));
    eventController.add(
      PowerQualityEvent.fromJson({'ev': 'lpf', 'pf': 0.70, 'ts': 200}),
    );
    await Future<void>.delayed(Duration.zero);

    clock = clock.add(const Duration(seconds: 61));
    eventController.add(
      PowerQualityEvent.fromJson({'ev': 'lpf', 'pf': 0.68, 'ts': 300}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notificationService.alerts, hasLength(2));
    expect(notificationService.alerts.first.title, 'Low Power Factor');
    expect(notificationService.alerts.last.body, contains('0.68'));
  });
}

class _FakeMeasurementRepository extends MeasurementRepository {
  final List<PowerQualityEvent> savedEvents = <PowerQualityEvent>[];

  @override
  Future<void> saveEvent(PowerQualityEvent event) async {
    savedEvents.add(event);
  }

  @override
  Future<void> clearEvents() async {
    savedEvents.clear();
  }
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super();
  final List<({int id, String title, String body})> alerts =
      <({int id, String title, String body})>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showAlert({
    required String title,
    required String body,
    required int id,
  }) async {
    alerts.add((id: id, title: title, body: body));
  }
}
