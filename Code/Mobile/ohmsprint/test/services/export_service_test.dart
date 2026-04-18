import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/core/models/measurement.dart';
import 'package:ohmsprint/core/models/metric_type.dart';
import 'package:ohmsprint/services/export_service.dart';

void main() {
  late Directory tempDir;
  late ExportService exportService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ohmsprint_export_test_');
    exportService = ExportService(
      temporaryDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generateCsv writes a readable CSV file', () async {
    final path = await exportService.generateCsv(
      _sampleMeasurements(),
      const [MetricType.voltage, MetricType.power],
    );

    final file = File(path);
    final contents = await file.readAsString();

    expect(await file.exists(), isTrue);
    expect(contents, contains('timestamp'));
    expect(contents, contains('V (V)'));
    expect(contents, contains('P (W)'));
    expect(contents, contains('2026-04-08'));
    expect(contents, contains('230.1'));
  });

  test('generatePdf writes a valid PDF file', () async {
    final path = await exportService.generatePdf(
      _sampleMeasurements(),
      const [MetricType.voltage, MetricType.frequency],
      DateTimeRange(
        start: DateTime(2026, 4, 8, 12, 0, 0),
        end: DateTime(2026, 4, 8, 12, 10, 0),
      ),
    );

    final file = File(path);
    final header = ascii.decode(await file.openRead(0, 5).first);

    expect(await file.exists(), isTrue);
    expect(header, '%PDF-');
    expect(await file.length(), greaterThan(1000));
  });
}

List<Measurement> _sampleMeasurements() {
  return const [
    Measurement(
      voltage: 230.1,
      current: 4.2,
      currentN: 4.0,
      activePower: 967,
      reactivePower: 48,
      apparentPower: 968,
      frequency: 50.01,
      powerFactor: 0.99,
      importEnergy: 1.2,
      exportEnergy: 0.0,
      timestamp: 1775649600000,
    ),
    Measurement(
      voltage: 229.7,
      current: 4.4,
      currentN: 4.1,
      activePower: 992,
      reactivePower: 51,
      apparentPower: 994,
      frequency: 49.98,
      powerFactor: 0.98,
      importEnergy: 1.3,
      exportEnergy: 0.0,
      timestamp: 1775649660000,
    ),
  ];
}
