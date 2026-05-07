import 'dart:math' as math;

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
    final voltage = _requireNumber(json, 'v', aliases: ['voltage']).toDouble();
    final current = _requireNumber(json, 'i', aliases: ['current']).toDouble();
    final activePower =
        _requireNumber(json, 'p', aliases: ['power']).toDouble();
    final apparentPower = _optionalNumber(json, 's')?.toDouble() ??
        (voltage * current).abs();
    final powerFactor = _optionalNumber(json, 'pf')?.toDouble() ??
        _derivePowerFactor(activePower, apparentPower);

    return Measurement(
      voltage: voltage,
      current: current,
      activePower: activePower,
      frequency:
          _requireNumber(json, 'f', aliases: ['frequency']).toDouble(),
      powerFactor: powerFactor,
      timestamp: _readTimestamp(json),
      currentN: _optionalNumber(json, 'in')?.toDouble() ?? 0,
      reactivePower: _optionalNumber(json, 'q')?.toDouble() ??
          _deriveReactivePower(activePower, apparentPower),
      apparentPower: apparentPower,
      importEnergy: (json['ei'] as num?)?.toDouble() ??
          (json['e'] as num?)?.toDouble() ??
          (json['power_usage'] as num?)?.toDouble() ??
          0,
      exportEnergy: (json['ee'] as num?)?.toDouble() ?? 0,
    );
  }

  static num _requireNumber(
    Map<String, dynamic> json,
    String key, {
    List<String> aliases = const [],
  }) {
    final value = _optionalNumber(json, key, aliases: aliases);
    if (value != null) {
      return value;
    }
    throw FormatException('Missing required numeric field: $key');
  }

  static num? _optionalNumber(
    Map<String, dynamic> json,
    String key, {
    List<String> aliases = const [],
  }) {
    for (final candidate in [key, ...aliases]) {
      final value = json[candidate];
      if (value is num) {
        return value;
      }
    }
    return null;
  }

  static int _readTimestamp(Map<String, dynamic> json) {
    final compactTimestamp = _optionalNumber(json, 't');
    if (compactTimestamp != null) {
      return compactTimestamp.toInt();
    }

    final verboseTimestamp = _optionalNumber(json, 'timestamp');
    if (verboseTimestamp == null) {
      throw const FormatException('Missing required numeric field: t');
    }

    final timestamp = verboseTimestamp.toInt();
    if (timestamp < 1000000000000) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    return timestamp;
  }

  static double _derivePowerFactor(double activePower, double apparentPower) {
    if (apparentPower == 0) {
      return 1;
    }
    return (activePower / apparentPower).clamp(-1, 1).toDouble();
  }

  static double _deriveReactivePower(double activePower, double apparentPower) {
    final reactiveMagnitude =
        (apparentPower * apparentPower) - (activePower * activePower);
    if (reactiveMagnitude <= 0) {
      return 0;
    }
    return math.sqrt(reactiveMagnitude);
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
