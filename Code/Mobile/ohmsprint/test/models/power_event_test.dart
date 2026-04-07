import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/power_event.dart';

void main() {
  test('parses sag event', () {
    final json = {'ev': 'sag', 'v': 218.3, 'ts': 12345};

    final event = PowerQualityEvent.fromJson(json);

    expect(event.type, EventType.sag);
    expect(event.severity, EventSeverity.warning);
    expect(event.description, contains('218.3'));
  });

  test('parses frequency event with formatted description', () {
    final json = {'ev': 'freq', 'f': 49.42, 'ts': 12345};

    final event = PowerQualityEvent.fromJson(json);

    expect(event.type, EventType.freq);
    expect(event.description, contains('49.42'));
  });

  test('marks low power factor as critical', () {
    final json = {'ev': 'lpf', 'pf': 0.68, 'ts': 12345};

    final event = PowerQualityEvent.fromJson(json);

    expect(event.type, EventType.lpf);
    expect(event.severity, EventSeverity.critical);
    expect(event.description, contains('0.68'));
  });

  test('throws on unsupported event type', () {
    final json = {'ev': 'unknown', 'v': 220.0, 'ts': 12345};

    expect(
      () => PowerQualityEvent.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
