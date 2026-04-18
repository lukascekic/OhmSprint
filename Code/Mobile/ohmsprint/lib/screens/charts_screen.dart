import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/measurement.dart';
import '../core/models/metric_type.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/downsampler.dart';
import '../core/utils/formatters.dart';
import '../providers/measurement_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/charts/live_line_chart.dart';
import '../widgets/charts/stats_row.dart';
import '../widgets/charts/time_range_selector.dart';
import '../widgets/common/glass_card.dart';

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  static const List<MetricType> _tabs = [
    MetricType.voltage,
    MetricType.current,
    MetricType.power,
    MetricType.frequency,
    MetricType.energy,
  ];

  MetricType _selectedMetric = MetricType.power;
  int _selectedRangeSeconds = 300;

  @override
  Widget build(BuildContext context) {
    final inMemoryHistory = ref.watch(measurementHistoryProvider);
    final repository = ref.read(measurementRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final fromTimestamp = now - (_selectedRangeSeconds * 1000);
    final rawHistory = _selectedRangeSeconds <= 900
        ? inMemoryHistory
            .where((measurement) => measurement.timestamp >= fromTimestamp)
            .toList()
        : repository.getRange(fromTimestamp, now);
    final chartHistory = _applyDownsampling(rawHistory);
    final hasData = chartHistory.isNotEmpty;
    final spots = _toSpots(chartHistory, _selectedMetric);
    final stats = ref.watch(
      statsProvider(
          (type: _selectedMetric, secondsBack: _selectedRangeSeconds)),
    );
    final currentValue =
        hasData ? chartHistory.last.valueFor(_selectedMetric) : 0.0;
    final minuteAgoMeasurement = _findClosestHistoricalValue(
      chartHistory,
      now - const Duration(minutes: 1).inMilliseconds,
    );
    final minuteAgoValue =
        minuteAgoMeasurement?.valueFor(_selectedMetric) ?? currentValue;
    final delta = currentValue - minuteAgoValue;
    final chartMinY = _chartMin(stats.min, currentValue);
    final chartMaxY = _chartMax(stats.max, currentValue);

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final metric = _tabs[index];
                    final isActive = metric == _selectedMetric;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _selectedMetric = metric),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? metric.color.withValues(alpha: 0.14)
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? metric.color.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          metric.color.withValues(alpha: 0.14),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            metric.label,
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 14,
                              color: isActive
                                  ? metric.color
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedMetric == MetricType.power
                          ? 'Active Load'
                          : _selectedMetric.label,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hasData
                              ? formatMetric(_selectedMetric, currentValue)
                              : '--',
                          style: AppTypography.monoLarge.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (hasData && _selectedMetric.unit.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _selectedMetric.unit,
                              style: AppTypography.headlineMedium.copyWith(
                                color: _selectedMetric.color,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (hasData)
                          _DeltaBadge(
                            delta: delta,
                            color: _selectedMetric.color,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!hasData) ...[
                      const _EmptyChartState(),
                      const SizedBox(height: 18),
                    ] else ...[
                      SizedBox(
                        height: 264,
                        child: LiveLineChart(
                          data: spots,
                          lineColor: _selectedMetric.color,
                          minY: chartMinY,
                          maxY: chartMaxY,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    TimeRangeSelector(
                      selectedSeconds: _selectedRangeSeconds,
                      onChanged: (seconds) {
                        setState(() => _selectedRangeSeconds = seconds);
                      },
                    ),
                    if (hasData) ...[
                      const SizedBox(height: 18),
                      StatsRow(
                        min: stats.min,
                        avg: stats.avg,
                        max: stats.max,
                        unit: _selectedMetric.unit,
                        accentColor: _selectedMetric.color,
                        formatter: (value) =>
                            formatMetric(_selectedMetric, value),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Measurement> _applyDownsampling(List<Measurement> source) {
    if (_selectedRangeSeconds <= 900) {
      return source;
    }

    if (_selectedRangeSeconds <= 3600) {
      return downsample(source, 1200);
    }

    return downsample(source, 1440);
  }

  List<FlSpot> _toSpots(List<Measurement> data, MetricType metricType) {
    return data
        .map(
          (measurement) => FlSpot(
            measurement.timestamp.toDouble(),
            measurement.valueFor(metricType),
          ),
        )
        .toList();
  }

  Measurement? _findClosestHistoricalValue(
    List<Measurement> history,
    int targetTimestamp,
  ) {
    if (history.isEmpty) {
      return null;
    }

    Measurement closest = history.first;
    var bestDistance = (closest.timestamp - targetTimestamp).abs();

    for (final measurement in history.skip(1)) {
      final distance = (measurement.timestamp - targetTimestamp).abs();
      if (distance < bestDistance) {
        closest = measurement;
        bestDistance = distance;
      }
    }

    return closest;
  }

  double _chartMin(double statsMin, double currentValue) {
    final minValue = statsMin < currentValue ? statsMin : currentValue;
    final maxValue = statsMin > currentValue ? statsMin : currentValue;
    if (minValue == maxValue) {
      return minValue - 1;
    }

    final padding = (maxValue - minValue).abs() * 0.12;
    return minValue - padding;
  }

  double _chartMax(double statsMax, double currentValue) {
    final minValue = statsMax < currentValue ? statsMax : currentValue;
    final maxValue = statsMax > currentValue ? statsMax : currentValue;
    if (minValue == maxValue) {
      return maxValue + 1;
    }

    final padding = (maxValue - minValue).abs() * 0.12;
    return maxValue + padding;
  }
}

class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No telemetry data yet',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 18,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a device or keep demo mode enabled to start plotting live measurements.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.delta,
    required this.color,
  });

  final double delta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final icon =
        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : ''}${delta.toStringAsFixed(2)}',
            style: AppTypography.monoSmall.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
