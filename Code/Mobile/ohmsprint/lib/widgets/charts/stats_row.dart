import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../common/metric_label.dart';
import '../common/metric_value.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({
    required this.min,
    required this.avg,
    required this.max,
    required this.unit,
    required this.accentColor,
    super.key,
    this.formatter,
  });

  final double min;
  final double avg;
  final double max;
  final String unit;
  final Color accentColor;
  final String Function(double value)? formatter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatsCell(
            label: 'Min',
            value: min,
            unit: unit,
            color: AppColors.onSurface,
            formatter: formatter,
          ),
        ),
        _StatsDivider(),
        Expanded(
          child: _StatsCell(
            label: 'Avg',
            value: avg,
            unit: unit,
            color: accentColor,
            formatter: formatter,
          ),
        ),
        _StatsDivider(),
        Expanded(
          child: _StatsCell(
            label: 'Max',
            value: max,
            unit: unit,
            color: AppColors.onSurface,
            formatter: formatter,
          ),
        ),
      ],
    );
  }
}

class _StatsCell extends StatelessWidget {
  const _StatsCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.formatter,
  });

  final String label;
  final double value;
  final String unit;
  final Color color;
  final String Function(double value)? formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MetricLabel(label, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        MetricValue(
          value: value,
          unit: unit,
          color: color,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          formatter: formatter,
        ),
      ],
    );
  }
}

class _StatsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.outlineVariant.withValues(alpha: 0.15),
    );
  }
}
