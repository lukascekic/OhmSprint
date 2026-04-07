import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SparklineWidget extends StatelessWidget {
  const SparklineWidget({
    required this.values,
    required this.color,
    super.key,
    this.onTap,
  });

  final List<double> values;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spots = values
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    final minY = values.isEmpty
        ? 0.0
        : values.reduce((left, right) => left < right ? left : right);
    final maxY = values.isEmpty
        ? 1.0
        : values.reduce((left, right) => left > right ? left : right);

    return GestureDetector(
      onTap: onTap,
      child: IgnorePointer(
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: spots.isEmpty ? 1 : (spots.length - 1).toDouble(),
            minY: minY == maxY ? minY - 1 : minY,
            maxY: minY == maxY ? maxY + 1 : maxY,
            backgroundColor: Colors.transparent,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.22,
                barWidth: 2,
                isStrokeCapRound: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.7),
                    color,
                  ],
                ),
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      ),
    );
  }
}
