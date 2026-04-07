import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/measurement.dart';
import '../core/models/metric_type.dart';
import 'measurement_provider.dart';

typedef MetricStats = ({double min, double max, double avg});
typedef StatsQuery = ({MetricType type, int secondsBack});

final statsProvider = Provider.family<MetricStats, StatsQuery>((ref, query) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final fromTimestamp = now - (query.secondsBack * 1000);

  if (query.secondsBack <= 3600) {
    final history = ref.watch(measurementHistoryProvider);
    final filtered = history
        .where((measurement) => measurement.timestamp >= fromTimestamp)
        .toList();
    return _buildStats(filtered, query.type);
  }

  return ref
      .read(measurementRepositoryProvider)
      .getStats(query.type, fromTimestamp, now);
});

MetricStats _buildStats(List<Measurement> data, MetricType type) {
  if (data.isEmpty) {
    return (min: 0, max: 0, avg: 0);
  }

  final values = data.map((measurement) => measurement.valueFor(type)).toList();
  final minValue = values.reduce((left, right) => left < right ? left : right);
  final maxValue = values.reduce((left, right) => left > right ? left : right);
  final avgValue = values.reduce((sum, value) => sum + value) / values.length;
  return (min: minValue, max: maxValue, avg: avgValue);
}
