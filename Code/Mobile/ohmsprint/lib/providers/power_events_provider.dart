import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/models/power_event.dart';
import '../services/measurement_repository.dart';
import 'connection_provider.dart';
import 'measurement_provider.dart';

final powerEventsProvider =
    StateNotifierProvider<PowerEventsNotifier, List<PowerQualityEvent>>((ref) {
  final notifier = PowerEventsNotifier(
    repository: ref.watch(measurementRepositoryProvider),
    eventStream: ref.watch(connectionProvider.notifier).eventStream,
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});

class PowerEventsNotifier extends StateNotifier<List<PowerQualityEvent>> {
  PowerEventsNotifier({
    required MeasurementRepository repository,
    required Stream<PowerQualityEvent> eventStream,
  })  : _repository = repository,
        super(const []) {
    _subscription = eventStream.listen(_onEvent);
  }

  final MeasurementRepository _repository;
  late final StreamSubscription<PowerQualityEvent> _subscription;

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
  }

  Future<void> clearEvents() async {
    state = const [];
    await _repository.clearEvents();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
