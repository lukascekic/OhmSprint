import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/models/power_event.dart';
import '../core/models/settings_model.dart';
import '../services/measurement_repository.dart';
import '../services/notification_service.dart';
import 'connection_provider.dart';
import 'measurement_provider.dart';
import 'settings_provider.dart';

final powerEventsProvider =
    StateNotifierProvider<PowerEventsNotifier, List<PowerQualityEvent>>((ref) {
  final notifier = PowerEventsNotifier(
    repository: ref.watch(measurementRepositoryProvider),
    eventStream: ref.watch(connectionProvider.notifier).eventStream,
    currentSettings: () => ref.read(settingsProvider),
    notificationService: ref.read(notificationServiceProvider),
  );
  return notifier;
});

class PowerEventsNotifier extends StateNotifier<List<PowerQualityEvent>> {
  PowerEventsNotifier({
    required MeasurementRepository repository,
    required Stream<PowerQualityEvent> eventStream,
    required this.currentSettings,
    required NotificationService notificationService,
    DateTime Function()? now,
  })  : _repository = repository,
        _notificationService = notificationService,
        _now = now ?? DateTime.now,
        super(const []) {
    _subscription = eventStream.listen(_onEvent);
  }

  final MeasurementRepository _repository;
  final NotificationService _notificationService;
  final DateTime Function() _now;
  final Map<EventType, DateTime> _lastNotificationByType =
      <EventType, DateTime>{};
  late final StreamSubscription<PowerQualityEvent> _subscription;
  final SettingsModel Function() currentSettings;

  void _onEvent(PowerQualityEvent event) {
    final nextState = [event, ...state];
    if (nextState.length > AppConstants.powerEventBufferSize) {
      nextState.removeRange(
        AppConstants.powerEventBufferSize,
        nextState.length,
      );
    }
    state = nextState;
    unawaited(
      _repository.saveEvent(event).catchError((error, stackTrace) {
        debugPrint('Failed to save power event: $error\n$stackTrace');
      }),
    );
    _notifyIfNeeded(event);
  }

  Future<void> clearEvents() async {
    state = const [];
    _lastNotificationByType.clear();
    await _repository.clearEvents();
  }

  void _notifyIfNeeded(PowerQualityEvent event) {
    final settings = currentSettings();
    if (!settings.notificationsEnabled) {
      return;
    }

    final now = _now();
    final lastSent = _lastNotificationByType[event.type];
    if (lastSent != null &&
        now.difference(lastSent) < const Duration(seconds: 60)) {
      return;
    }

    final alert = _buildAlertPayload(event);

    _lastNotificationByType[event.type] = now;
    unawaited(
      _notificationService
          .showAlert(
        title: alert.title,
        body: alert.body,
        id: event.type.index + 1,
      )
          .catchError((error, stackTrace) {
        debugPrint('Failed to show notification: $error\n$stackTrace');
      }),
    );
  }

  ({String title, String body}) _buildAlertPayload(PowerQualityEvent event) {
    return switch (event.type) {
      EventType.sag => (
          title: 'Voltage Sag',
          body: event.description,
        ),
      EventType.swell => (
          title: 'Voltage Swell',
          body: event.description,
        ),
      EventType.freq => (
          title: 'Frequency Deviation',
          body: event.description,
        ),
      EventType.lpf => (
          title: 'Low Power Factor',
          body: event.description,
        ),
    };
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
