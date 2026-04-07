import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/models/measurement.dart';
import '../core/models/metric_type.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/measurement_provider.dart';
import '../services/export_service.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/metric_label.dart';

enum _ExportFormat { csv, pdf }

final exportMeasurementsProvider =
    Provider.family<List<Measurement>, DateTimeRange>((ref, range) {
  final repository = ref.read(measurementRepositoryProvider);
  final history = ref.watch(measurementHistoryProvider);
  final from = range.start.millisecondsSinceEpoch;
  final to = range.end.millisecondsSinceEpoch;
  final persisted = repository.getRange(from, to);
  final liveTail = history.where((measurement) {
    return measurement.timestamp >= from && measurement.timestamp <= to;
  });

  final merged = <int, Measurement>{};
  for (final measurement in persisted) {
    merged[measurement.timestamp] = measurement;
  }
  for (final measurement in liveTail) {
    merged[measurement.timestamp] = measurement;
  }

  final sorted = merged.values.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return sorted;
});

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late DateTimeRange _range;
  late Set<MetricType> _selectedMetrics;
  _ExportFormat _format = _ExportFormat.pdf;
  bool _isGenerating = false;
  String? _generatedPath;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 1)),
      end: now,
    );
    _selectedMetrics = {
      MetricType.voltage,
      MetricType.current,
      MetricType.power,
      MetricType.frequency,
      MetricType.energy,
    };
  }

  @override
  Widget build(BuildContext context) {
    final exportService = ref.read(exportServiceProvider);
    final data = ref.watch(exportMeasurementsProvider(_range));
    final previewRows = data.length;

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Data Synthesis',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 32,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ANALYTICAL OUTPUT',
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 24),
              _ExportSection(
                icon: Icons.calendar_today_rounded,
                iconColor: AppColors.primary,
                title: 'Temporal Range',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DateTile(
                            label: 'From',
                            date: _range.start,
                            onTap: () => _pickBoundary(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTile(
                            label: 'To',
                            date: _range.end,
                            onTap: () => _pickBoundary(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickRangeChip(
                          label: 'Last 24h',
                          selected: _matchesRange(const Duration(days: 1)),
                          onTap: () => _setQuickRange(const Duration(days: 1)),
                        ),
                        _QuickRangeChip(
                          label: 'Last 7 Days',
                          selected: _matchesRange(const Duration(days: 7)),
                          onTap: () => _setQuickRange(const Duration(days: 7)),
                        ),
                        _QuickRangeChip(
                          label: 'Last 30 Days',
                          selected: _matchesRange(const Duration(days: 30)),
                          onTap: () => _setQuickRange(const Duration(days: 30)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ExportSection(
                icon: Icons.checklist_rounded,
                iconColor: AppColors.secondary,
                title: 'Telemetry Nodes',
                child: Column(
                  children: [
                    for (final metric in MetricType.values)
                      _MetricToggleRow(
                        metric: metric,
                        selected: _selectedMetrics.contains(metric),
                        onTap: () => _toggleMetric(metric),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ExportSection(
                icon: Icons.file_open_rounded,
                iconColor: AppColors.tertiary,
                title: 'Output Encapsulation',
                child: Row(
                  children: [
                    Expanded(
                      child: _FormatCard(
                        label: 'PDF',
                        subtitle: 'High fidelity',
                        icon: Icons.picture_as_pdf_rounded,
                        selected: _format == _ExportFormat.pdf,
                        onTap: () =>
                            setState(() => _format = _ExportFormat.pdf),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FormatCard(
                        label: 'CSV',
                        subtitle: 'Raw data',
                        icon: Icons.table_chart_rounded,
                        selected: _format == _ExportFormat.csv,
                        onTap: () =>
                            setState(() => _format = _ExportFormat.csv),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MetricLabel('Live Preview'),
                    const SizedBox(height: 14),
                    _PreviewStat(label: 'Rows', value: '$previewRows'),
                    _PreviewStat(
                      label: 'Range',
                      value:
                          '${_dateFormat.format(_range.start)} -> ${_dateFormat.format(_range.end)}',
                    ),
                    _PreviewStat(
                      label: 'Metrics',
                      value: _selectedMetrics.isEmpty
                          ? 'None selected'
                          : _selectedMetrics
                              .map((metric) => metric.shortLabel)
                              .join(', '),
                    ),
                    _PreviewStat(
                      label: 'Format',
                      value: _format == _ExportFormat.pdf ? 'PDF' : 'CSV',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      previewRows == 0
                          ? 'No cached telemetry matches this range yet.'
                          : 'Report will be built from locally cached telemetry only.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _isGenerating || _selectedMetrics.isEmpty || data.isEmpty
                        ? null
                        : () => _generateReport(exportService, data),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surfaceDim,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_rounded),
                label:
                    Text(_isGenerating ? 'Generating...' : 'Generate Report'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _generatedPath == null || _isGenerating
                    ? null
                    : () => exportService.shareFile(_generatedPath!),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesRange(Duration duration) {
    final difference = _range.duration - duration;
    return difference.abs() <= const Duration(minutes: 30);
  }

  void _setQuickRange(Duration duration) {
    final now = DateTime.now();
    setState(() {
      _range = DateTimeRange(start: now.subtract(duration), end: now);
    });
  }

  Future<void> _pickBoundary({required bool isStart}) async {
    final current = isStart ? _range.start : _range.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _range = DateTimeRange(
          start: DateTime(picked.year, picked.month, picked.day),
          end: _range.end.isBefore(picked) ? picked : _range.end,
        );
      } else {
        final nextEnd = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
        _range = DateTimeRange(
          start: _range.start.isAfter(nextEnd) ? nextEnd : _range.start,
          end: nextEnd,
        );
      }
    });
  }

  void _toggleMetric(MetricType metric) {
    setState(() {
      if (_selectedMetrics.contains(metric)) {
        _selectedMetrics.remove(metric);
      } else {
        _selectedMetrics.add(metric);
      }
    });
  }

  Future<void> _generateReport(
    ExportService exportService,
    List<Measurement> data,
  ) async {
    setState(() => _isGenerating = true);

    try {
      final selectedMetrics = _selectedMetrics.toList(growable: false);
      final path = _format == _ExportFormat.csv
          ? await exportService.generateCsv(data, selectedMetrics)
          : await exportService.generatePdf(data, selectedMetrics, _range);
      if (!mounted) {
        return;
      }
      setState(() => _generatedPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Report generated: ${path.split(RegExp(r'[\\/]')).last}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate report: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: AppTypography.monoSmall.copyWith(
                color: iconColor,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(child: child),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _dateFormat.format(date),
              style: AppTypography.monoMedium.copyWith(
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickRangeChip extends StatelessWidget {
  const _QuickRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      backgroundColor: AppColors.surfaceContainerHigh,
      labelStyle: AppTypography.monoSmall.copyWith(
        color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
        fontSize: 11,
      ),
    );
  }
}

class _MetricToggleRow extends StatelessWidget {
  const _MetricToggleRow({
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  final MetricType metric;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? metric.color.withValues(alpha: 0.1)
                : AppColors.surfaceContainerHigh.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? metric.color.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? metric.color : AppColors.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  metric.label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                metric.shortLabel,
                style: AppTypography.monoSmall.copyWith(
                  color: metric.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceContainerHigh.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.onSurface),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTypography.monoMedium.copyWith(
                color: AppColors.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: MetricLabel(label),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
