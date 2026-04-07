import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../core/models/measurement.dart';
import '../core/models/metric_type.dart';
import '../core/models/power_event.dart';
import '../core/models/settings_model.dart';

class MeasurementRepository {
  static const String measurementsBoxName = 'measurements';
  static const String eventsBoxName = 'events';
  static const String settingsBoxName = 'settings';

  late Box<String> _measurementsBox;
  late Box<String> _eventsBox;
  late Box<dynamic> _settingsBox;

  Future<void> init() async {
    _measurementsBox = await Hive.openBox<String>(measurementsBoxName);
    _eventsBox = await Hive.openBox<String>(eventsBoxName);
    _settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
  }

  Future<void> saveBatch(List<Measurement> batch) async {
    final entries = <String, String>{};
    for (final measurement in batch) {
      final key = _nextMeasurementKey(measurement.timestamp, entries);
      entries[key] = jsonEncode(measurement.toJson());
    }
    if (entries.isNotEmpty) {
      await _measurementsBox.putAll(entries);
    }
  }

  Future<void> saveEvent(PowerQualityEvent event) async {
    await _eventsBox.put(
      _nextEventKey(event.timestamp),
      jsonEncode(event.toJson()),
    );
  }

  List<Measurement> getRange(int fromTimestamp, int toTimestamp) {
    final records = <Measurement>[];
    for (final key in _measurementsBox.keys) {
      final timestamp = int.tryParse(key.toString().split('_').first);
      if (timestamp == null ||
          timestamp < fromTimestamp ||
          timestamp > toTimestamp) {
        continue;
      }

      final raw = _measurementsBox.get(key);
      if (raw == null) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          records.add(Measurement.fromJson(decoded));
        } else if (decoded is Map) {
          records.add(Measurement.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } on FormatException {
        continue;
      }
    }

    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return records;
  }

  ({double min, double max, double avg}) getStats(
    MetricType type,
    int fromTimestamp,
    int toTimestamp,
  ) {
    final data = getRange(fromTimestamp, toTimestamp);
    if (data.isEmpty) {
      return (min: 0, max: 0, avg: 0);
    }

    final values =
        data.map((measurement) => measurement.valueFor(type)).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final avgValue = values.reduce((sum, value) => sum + value) / values.length;
    return (min: minValue, max: maxValue, avg: avgValue);
  }

  Future<void> clearAll() async {
    await _measurementsBox.clear();
    await _eventsBox.clear();
    await _settingsBox.clear();
  }

  SettingsModel loadSettings() {
    final raw = Map<String, dynamic>.from(_settingsBox.toMap());
    return SettingsModel.fromJson(raw);
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await _settingsBox.clear();
    await _settingsBox.putAll(Map<dynamic, dynamic>.from(settings.toJson()));
  }

  Future<void> clearEvents() async {
    await _eventsBox.clear();
  }

  String _nextMeasurementKey(
    int timestamp,
    Map<String, String> pendingEntries,
  ) {
    var suffix = 0;
    while (true) {
      final key = suffix == 0 ? '$timestamp' : '${timestamp}_$suffix';
      if (!pendingEntries.containsKey(key) &&
          !_measurementsBox.containsKey(key)) {
        return key;
      }
      suffix += 1;
    }
  }

  String _nextEventKey(int timestamp) {
    var suffix = 0;
    while (true) {
      final key = suffix == 0 ? '$timestamp' : '${timestamp}_$suffix';
      if (!_eventsBox.containsKey(key)) {
        return key;
      }
      suffix += 1;
    }
  }
}
