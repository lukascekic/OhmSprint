enum EventType { sag, swell, freq, lpf }

enum EventSeverity { warning, critical }

class PowerQualityEvent {
  const PowerQualityEvent({
    required this.type,
    required this.values,
    required this.timestamp,
    required this.severity,
    required this.description,
  });

  final EventType type;
  final Map<String, double> values;
  final int timestamp;
  final EventSeverity severity;
  final String description;

  factory PowerQualityEvent.fromJson(Map<String, dynamic> json) {
    final type = EventType.values.firstWhere(
      (value) => value.name == json['ev'],
      orElse: () =>
          throw FormatException('Unsupported event type: ${json['ev']}'),
    );

    final values = <String, double>{};
    const allowedValueKeys = {'v', 'f', 'pf'};
    json.forEach((key, value) {
      if (key == 'ev' || key == 'ts' || !allowedValueKeys.contains(key)) {
        return;
      }
      if (value is num) {
        values[key] = value.toDouble();
      }
    });

    return PowerQualityEvent(
      type: type,
      values: values,
      timestamp: (json['ts'] as num?)?.toInt() ?? 0,
      severity: switch (type) {
        EventType.lpf => EventSeverity.critical,
        EventType.sag ||
        EventType.swell ||
        EventType.freq =>
          EventSeverity.warning,
      },
      description: _buildDescription(type, values),
    );
  }

  static String _buildDescription(EventType type, Map<String, double> values) {
    return switch (type) {
      EventType.sag =>
        'Voltage sag detected (${values['v']?.toStringAsFixed(1) ?? '--'}V)',
      EventType.swell =>
        'Voltage swell detected (${values['v']?.toStringAsFixed(1) ?? '--'}V)',
      EventType.freq =>
        'Frequency deviation detected (${values['f']?.toStringAsFixed(2) ?? '--'} Hz)',
      EventType.lpf =>
        'Low power factor detected (${values['pf']?.toStringAsFixed(2) ?? '--'})',
    };
  }
}
