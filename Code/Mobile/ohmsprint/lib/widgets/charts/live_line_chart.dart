import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class LiveLineChart extends StatelessWidget {
  const LiveLineChart({
    required this.data,
    required this.lineColor,
    required this.minY,
    required this.maxY,
    super.key,
  });

  final List<FlSpot> data;
  final Color lineColor;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'Waiting for data...',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    final minX = data.first.x;
    final maxX = data.last.x;
    final safeMaxY = maxY <= minY ? minY + 1 : maxY;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: safeMaxY,
        clipData: const FlClipData.all(),
        backgroundColor: Colors.transparent,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (safeMaxY - minY) / 4,
          verticalInterval: (maxX - minX) <= 0 ? 1 : (maxX - minX) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: const FlTitlesData(
          show: false,
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceContainerHigh,
            tooltipRoundedRadius: 12,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  AppTypography.monoSmall.copyWith(
                    color: AppColors.onSurface,
                  ),
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: lineColor.withValues(alpha: 0.18),
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, bar, spotIndex) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.onSurface,
                      strokeWidth: 2,
                      strokeColor: lineColor,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            curveSmoothness: 0.2,
            barWidth: 2.6,
            isStrokeCapRound: true,
            gradient: LinearGradient(
              colors: [
                lineColor.withValues(alpha: 0.7),
                lineColor,
              ],
            ),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => spot == data.last,
              getDotPainter: (spot, percent, bar, spotIndex) {
                return FlDotCirclePainter(
                  radius: 3.8,
                  color: lineColor,
                  strokeWidth: 2,
                  strokeColor: AppColors.onSurface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.2),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}
