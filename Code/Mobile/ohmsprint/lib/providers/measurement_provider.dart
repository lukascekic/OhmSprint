import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/models/measurement.dart';
import '../services/measurement_repository.dart';
import 'connection_provider.dart';

final measurementRepositoryProvider = Provider<MeasurementRepository>((ref) {
  throw UnimplementedError(
    'measurementRepositoryProvider must be overridden in main.dart',
  );
});

final measurementStreamProvider = StreamProvider<Measurement>((ref) {
  return ref.watch(connectionProvider.notifier).measurementStream;
});

final measurementHistoryProvider =
    StateNotifierProvider<MeasurementHistoryNotifier, List<Measurement>>((ref) {
  final notifier = MeasurementHistoryNotifier(
    repository: ref.watch(measurementRepositoryProvider),
    measurementStream: ref.watch(connectionProvider.notifier).measurementStream,
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});

final latestMeasurementProvider = Provider<Measurement?>((ref) {
  final history = ref.watch(measurementHistoryProvider);
  return history.isEmpty ? null : history.last;
});

class MeasurementHistoryNotifier extends StateNotifier<List<Measurement>>
    with WidgetsBindingObserver {
  MeasurementHistoryNotifier({
    required MeasurementRepository repository,
    required Stream<Measurement> measurementStream,
  })  : _repository = repository,
        super(const []) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = measurementStream.listen(_onMeasurement);
    _flushTimer = Timer.periodic(AppConstants.hiveFlushInterval, (_) {
      if (_isDisposed) {
        return;
      }
      unawaited(flushPending());
    });
  }

  final MeasurementRepository _repository;
  final List<Measurement> _pendingMeasurements = <Measurement>[];
  late final StreamSubscription<Measurement> _subscription;
  Timer? _flushTimer;
  bool _isDisposed = false;

  void _onMeasurement(Measurement measurement) {
    final nextState = [...state, measurement];
    if (nextState.length > AppConstants.historyBufferSize) {
      nextState.removeRange(
        0,
        nextState.length - AppConstants.historyBufferSize,
      );
    }
    state = nextState;
    _pendingMeasurements.add(measurement);
  }

  Future<void> flushPending() async {
    if (_pendingMeasurements.isEmpty) {
      return;
    }

    final batch = List<Measurement>.from(_pendingMeasurements);
    _pendingMeasurements.clear();
    await _repository.saveBatch(batch);
  }

  Future<void> clearHistory() async {
    state = const [];
    _pendingMeasurements.clear();
    await _repository.clearMeasurements();
  }

  List<Measurement> getPersistedRange(int fromTimestamp, int toTimestamp) {
    return _repository.getRange(fromTimestamp, toTimestamp);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flushPending());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _subscription.cancel();
    unawaited(flushPending());
    super.dispose();
  }
}
