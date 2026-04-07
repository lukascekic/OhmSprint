import 'package:intl/intl.dart';

import '../models/metric_type.dart';

final NumberFormat _oneDecimalFormatter = NumberFormat('0.0');
final NumberFormat _twoDecimalFormatter = NumberFormat('0.00');
final NumberFormat _threeDecimalFormatter = NumberFormat('0.000');
final NumberFormat _zeroDecimalFormatter = NumberFormat('0');

String formatMetric(MetricType type, double value) {
  if (!value.isFinite) {
    return '--';
  }

  final formatter = switch (type) {
    MetricType.voltage => _oneDecimalFormatter,
    MetricType.current => _twoDecimalFormatter,
    MetricType.power =>
      value.abs() >= 100 ? _zeroDecimalFormatter : _oneDecimalFormatter,
    MetricType.reactivePower =>
      value.abs() >= 100 ? _zeroDecimalFormatter : _oneDecimalFormatter,
    MetricType.apparentPower =>
      value.abs() >= 100 ? _zeroDecimalFormatter : _oneDecimalFormatter,
    MetricType.frequency => _twoDecimalFormatter,
    MetricType.energy => _twoDecimalFormatter,
    MetricType.powerFactor => _threeDecimalFormatter,
  };

  return formatter.format(value);
}
