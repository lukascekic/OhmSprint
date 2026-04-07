import 'package:flutter/material.dart';

import '../../core/models/metric_type.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../common/glass_card.dart';
import '../common/metric_label.dart';
import '../common/metric_value.dart';

class MiniMetricCard extends StatelessWidget {
  const MiniMetricCard({
    required this.metricType,
    required this.value,
    required this.icon,
    super.key,
    this.formatter,
    this.progress,
  });

  final MetricType metricType;
  final double value;
  final IconData icon;
  final String Function(double value)? formatter;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress ?? _normalizedValue();

    return GlassCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: metricType.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: metricType.color,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MetricLabel(metricType.label),
          const SizedBox(height: 10),
          MetricValue(
            value: value,
            unit: metricType.unit,
            color: metricType.color,
            style: AppTypography.monoMedium.copyWith(
              color: AppColors.onSurface,
            ),
            formatter: formatter,
          ),
          const SizedBox(height: 16),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: normalizedProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          metricType.color.withValues(alpha: 0.75),
                          metricType.color,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: metricType.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _normalizedValue() {
    final span = metricType.maxValue - metricType.minValue;
    if (span <= 0) {
      return 0;
    }

    return ((value - metricType.minValue) / span).clamp(0, 1);
  }
}
