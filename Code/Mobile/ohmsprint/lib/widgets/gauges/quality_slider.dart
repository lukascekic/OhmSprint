import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class QualitySlider extends StatelessWidget {
  const QualitySlider({
    required this.value,
    required this.min,
    required this.nominal,
    required this.max,
    required this.normalColor,
    super.key,
  });

  final double value;
  final double min;
  final double nominal;
  final double max;
  final Color normalColor;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(min, max);
    final normalized = max > min ? ((clampedValue - min) / (max - min)) : 0.0;
    const markerSize = 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final markerLeft = (constraints.maxWidth - markerSize) * normalized;

            return SizedBox(
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(color: AppColors.error),
                            ),
                            Expanded(
                              child: Container(color: normalColor),
                            ),
                            Expanded(
                              child: Container(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    top: 5,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: BoxDecoration(
                        color: AppColors.onSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: normalColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: normalColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _format(min),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              _format(nominal),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            Text(
              _format(max),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _format(double input) {
    if ((input - input.roundToDouble()).abs() < 0.001) {
      return input.toStringAsFixed(0);
    }

    return input.toStringAsFixed(1);
  }
}
