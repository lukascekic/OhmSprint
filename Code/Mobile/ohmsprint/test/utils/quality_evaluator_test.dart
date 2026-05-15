import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/metric_type.dart';
import 'package:ohmsprint/core/models/settings_model.dart';
import 'package:ohmsprint/core/utils/quality_evaluator.dart';

void main() {
  test('voltage 230V is normal', () {
    expect(evaluateQuality(MetricType.voltage, 230.0), QualityLevel.normal);
  });

  test('voltage 215V is warning', () {
    expect(evaluateQuality(MetricType.voltage, 215.0), QualityLevel.warning);
  });

  test('voltage 205V is critical', () {
    expect(evaluateQuality(MetricType.voltage, 205.0), QualityLevel.critical);
  });

  test('frequency 49.7Hz is warning', () {
    expect(evaluateQuality(MetricType.frequency, 49.7), QualityLevel.warning);
  });

  test('frequency 49.4Hz is critical', () {
    expect(evaluateQuality(MetricType.frequency, 49.4), QualityLevel.critical);
  });

  test('power factor 0.85 is warning', () {
    expect(evaluateQuality(MetricType.powerFactor, 0.85), QualityLevel.warning);
  });

  test('current defaults to normal quality', () {
    expect(evaluateQuality(MetricType.current, 12.0), QualityLevel.normal);
  });

  test('uses custom voltage threshold from settings', () {
    const settings = SettingsModel(voltageThreshold: 5);

    expect(
      evaluateQuality(MetricType.voltage, 243.0, settings: settings),
      QualityLevel.critical,
    );
  });

  test('uses custom frequency threshold from settings', () {
    const settings = SettingsModel(freqThreshold: 1.0);

    expect(
      evaluateQuality(MetricType.frequency, 49.59, settings: settings),
      QualityLevel.warning,
    );
    expect(
      evaluateQuality(MetricType.frequency, 49.7, settings: settings),
      QualityLevel.normal,
    );
  });

  test('uses custom power factor threshold from settings', () {
    const settings = SettingsModel(pfThreshold: 0.9);

    expect(
      evaluateQuality(MetricType.powerFactor, 0.88, settings: settings),
      QualityLevel.critical,
    );
  });
}
