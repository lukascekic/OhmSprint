import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/metric_type.dart';
import 'package:ohmsprint/core/utils/formatters.dart';

void main() {
  test('voltage formats to 1 decimal', () {
    expect(formatMetric(MetricType.voltage, 230.156), '230.2');
  });

  test('current formats to 2 decimals', () {
    expect(formatMetric(MetricType.current, 4.1), '4.10');
  });

  test('power formats to 0 decimals for large values', () {
    expect(formatMetric(MetricType.power, 967.2), '967');
  });

  test('power formats to 1 decimal below 100W', () {
    expect(formatMetric(MetricType.power, 99.9), '99.9');
  });

  test('invalid numeric values render placeholder', () {
    expect(formatMetric(MetricType.frequency, double.nan), '--');
  });
}
