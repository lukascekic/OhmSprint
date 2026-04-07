import 'metric_type.dart';

class Measurement {
  const Measurement({
    required this.voltage,
    required this.current,
    required this.currentN,
    required this.activePower,
    required this.reactivePower,
    required this.apparentPower,
    required this.frequency,
    required this.powerFactor,
    required this.importEnergy,
    required this.exportEnergy,
    required this.timestamp,
  });

  final double voltage;
  final double current;
  final double currentN;
  final double activePower;
  final double reactivePower;
  final double apparentPower;
  final double frequency;
  final double powerFactor;
  final double importEnergy;
  final double exportEnergy;
  final int timestamp;

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      voltage: _requireNumber(json, 'v').toDouble(),
      current: _requireNumber(json, 'i').toDouble(),
      activePower: _requireNumber(json, 'p').toDouble(),
      frequency: _requireNumber(json, 'f').toDouble(),
      powerFactor: _requireNumber(json, 'pf').toDouble(),
      timestamp: _requireNumber(json, 't').toInt(),
      currentN: (json['in'] as num?)?.toDouble() ?? 0,
      reactivePower: (json['q'] as num?)?.toDouble() ?? 0,
      apparentPower: (json['s'] as num?)?.toDouble() ?? 0,
      importEnergy: (json['ei'] as num?)?.toDouble() ??
          (json['e'] as num?)?.toDouble() ??
          0,
      exportEnergy: (json['ee'] as num?)?.toDouble() ?? 0,
    );
  }

  static num _requireNumber(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) {
      return value;
    }
    throw FormatException('Missing required numeric field: $key');
  }

  Map<String, dynamic> toJson() {
    return {
      'v': voltage,
      'i': current,
      'in': currentN,
      'p': activePower,
      'q': reactivePower,
      's': apparentPower,
      'f': frequency,
      'pf': powerFactor,
      'ei': importEnergy,
      'ee': exportEnergy,
      't': timestamp,
    };
  }

  double valueFor(MetricType type) {
    switch (type) {
      case MetricType.voltage:
        return voltage;
      case MetricType.current:
        return current;
      case MetricType.power:
        return activePower;
      case MetricType.reactivePower:
        return reactivePower;
      case MetricType.apparentPower:
        return apparentPower;
      case MetricType.frequency:
        return frequency;
      case MetricType.energy:
        return importEnergy;
      case MetricType.powerFactor:
        return powerFactor;
    }
  }
}
