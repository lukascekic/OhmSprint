import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/metric_type.dart';
import 'package:ohmsprint/core/models/measurement.dart';

void main() {
  group('Measurement.fromJson', () {
    test('parses valid JSON with all fields', () {
      final json = {
        'v': 230.15,
        'i': 4.123,
        'in': 4.1,
        'p': 948.0,
        'q': 52.0,
        's': 949.0,
        'f': 50.01,
        'pf': 0.999,
        'ei': 1.23,
        'ee': 0.05,
        't': 1234567890,
      };

      final measurement = Measurement.fromJson(json);

      expect(measurement.voltage, 230.15);
      expect(measurement.current, 4.123);
      expect(measurement.currentN, 4.1);
      expect(measurement.activePower, 948.0);
      expect(measurement.frequency, 50.01);
      expect(measurement.powerFactor, 0.999);
      expect(measurement.importEnergy, 1.23);
      expect(measurement.exportEnergy, 0.05);
    });

    test('handles integer values', () {
      final json = {
        'v': 230,
        'i': 4,
        'in': 4,
        'p': 948,
        'q': 52,
        's': 949,
        'f': 50,
        'pf': 1,
        'ei': 1,
        'ee': 0,
        't': 1234567890,
      };

      final measurement = Measurement.fromJson(json);

      expect(measurement.voltage, 230.0);
    });

    test('handles negative power (export/reverse)', () {
      final json = {
        'v': 230.0,
        'i': 4.0,
        'in': 4.0,
        'p': -150.0,
        'q': -10.0,
        's': 150.0,
        'f': 50.0,
        'pf': -0.99,
        'ei': 0.0,
        'ee': 1.5,
        't': 1234567890,
      };

      final measurement = Measurement.fromJson(json);

      expect(measurement.activePower, -150.0);
    });

    test('handles minimal payload (required fields only)', () {
      final json = {
        'v': 230.0,
        'i': 4.0,
        'p': 920.0,
        'f': 50.0,
        'pf': 0.99,
        't': 1234567890,
      };

      final measurement = Measurement.fromJson(json);

      expect(measurement.voltage, 230.0);
      expect(measurement.reactivePower, 0.0);
      expect(measurement.importEnergy, 0.0);
    });

    test('maps legacy "e" field to importEnergy', () {
      final json = {
        'v': 230.0,
        'i': 4.0,
        'p': 920.0,
        'f': 50.0,
        'pf': 0.99,
        'e': 123.45,
        't': 1234567890,
      };

      final measurement = Measurement.fromJson(json);

      expect(measurement.importEnergy, 123.45);
    });

    test('parses firmware measurement payload', () {
      final beforeParse = DateTime.now().millisecondsSinceEpoch;
      final measurement = Measurement.fromJson({
        'voltage': 230.0,
        'current': 4.0,
        'power': 874.0,
        'frequency': 50.0,
        'power_usage': 1.25,
        'timestamp': 42,
      });
      final afterParse = DateTime.now().millisecondsSinceEpoch;

      expect(measurement.voltage, 230.0);
      expect(measurement.current, 4.0);
      expect(measurement.activePower, 874.0);
      expect(measurement.apparentPower, 920.0);
      expect(measurement.powerFactor, closeTo(0.95, 0.001));
      expect(measurement.importEnergy, 1.25);
      expect(measurement.timestamp, inInclusiveRange(beforeParse, afterParse));
    });

    test('throws descriptive error when required field is missing', () {
      final json = {
        'i': 4.0,
        'p': 920.0,
        'f': 50.0,
        'pf': 0.99,
        't': 1234567890,
      };

      expect(
        () => Measurement.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('v'),
          ),
        ),
      );
    });

    test('returns values by metric type', () {
      final measurement = Measurement.fromJson({
        'v': 230.0,
        'i': 4.0,
        'in': 3.9,
        'p': 920.0,
        'q': 12.0,
        's': 921.0,
        'f': 50.0,
        'pf': 0.99,
        'ei': 12.5,
        'ee': 0.1,
        't': 1234567890,
      });

      expect(measurement.valueFor(MetricType.current), 4.0);
      expect(measurement.valueFor(MetricType.energy), 12.5);
    });
  });
}
