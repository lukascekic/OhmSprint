import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/models/measurement.dart';
import '../core/models/metric_type.dart';
import '../core/utils/downsampler.dart';
import '../core/utils/formatters.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return const ExportService();
});

class ExportService {
  const ExportService();

  static const int pdfRowLimit = 10000;

  Future<String> generateCsv(
    List<Measurement> data,
    List<MetricType> metrics,
  ) async {
    final rows = <List<dynamic>>[
      [
        'timestamp',
        ...metrics.map((metric) => '${metric.shortLabel} (${metric.unit})'),
      ],
      ...data.map(
        (measurement) => [
          _timestampFormat.format(
            DateTime.fromMillisecondsSinceEpoch(measurement.timestamp),
          ),
          ...metrics.map(
            (metric) => formatMetric(metric, measurement.valueFor(metric)),
          ),
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final file = await _createFile('csv');
    await file.writeAsString(csv);
    return file.path;
  }

  Future<String> generatePdf(
    List<Measurement> data,
    List<MetricType> metrics,
    DateTimeRange range,
  ) async {
    final document = pw.Document();
    final exportData =
        data.length > pdfRowLimit ? downsample(data, pdfRowLimit) : data;
    final stats = _buildStats(exportData, metrics);

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          pw.Text(
            'OHMSPRINT',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue300,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Data Synthesis Report',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Range: ${_dateOnlyFormat.format(range.start)} - ${_dateOnlyFormat.format(range.end)}',
                ),
                pw.Text('Rows: ${exportData.length}'),
                pw.Text(
                  'Metrics: ${metrics.map((metric) => metric.shortLabel).join(', ')}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Metric Summary',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Min', 'Avg', 'Max'],
            data: [
              for (final metric in metrics)
                [
                  metric.label,
                  stats[metric]!.$1,
                  stats[metric]!.$2,
                  stats[metric]!.$3,
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Telemetry Rows',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [
              'Timestamp',
              ...metrics.map((metric) => metric.shortLabel),
            ],
            data: [
              for (final measurement in exportData)
                [
                  _timestampFormat.format(
                    DateTime.fromMillisecondsSinceEpoch(measurement.timestamp),
                  ),
                  ...metrics.map(
                    (metric) =>
                        formatMetric(metric, measurement.valueFor(metric)),
                  ),
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue300,
            ),
          ),
        ],
      ),
    );

    final file = await _createFile('pdf');
    await file.writeAsBytes(await document.save());
    return file.path;
  }

  Future<void> shareFile(String path) async {
    await Share.shareXFiles([XFile(path)]);
  }

  Map<MetricType, (String, String, String)> _buildStats(
    List<Measurement> data,
    List<MetricType> metrics,
  ) {
    final result = <MetricType, (String, String, String)>{};
    for (final metric in metrics) {
      if (data.isEmpty) {
        result[metric] = ('--', '--', '--');
        continue;
      }

      final values = data.map((measurement) => measurement.valueFor(metric));
      final minValue =
          values.reduce((left, right) => left < right ? left : right);
      final maxValue =
          values.reduce((left, right) => left > right ? left : right);
      final average = data
              .map((measurement) => measurement.valueFor(metric))
              .reduce((a, b) => a + b) /
          data.length;
      result[metric] = (
        formatMetric(metric, minValue),
        formatMetric(metric, average),
        formatMetric(metric, maxValue),
      );
    }
    return result;
  }

  Future<File> _createFile(String extension) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'ohmsprint-export-${DateTime.now().millisecondsSinceEpoch}.$extension';
    return File('${tempDir.path}${Platform.pathSeparator}$fileName');
  }
}

final DateFormat _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
final DateFormat _dateOnlyFormat = DateFormat('yyyy-MM-dd');
