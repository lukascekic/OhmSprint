import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

class MetricValue extends StatelessWidget {
  const MetricValue({
    required this.value,
    required this.unit,
    required this.color,
    required this.style,
    super.key,
    this.formatter,
  });

  final double value;
  final String unit;
  final Color color;
  final TextStyle style;
  final String Function(double value)? formatter;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, animatedValue, child) {
        final displayValue =
            formatter?.call(animatedValue) ?? _defaultFormat(animatedValue);

        return Semantics(
          label: '${formatter?.call(value) ?? _defaultFormat(value)} $unit',
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayValue,
                  style: style,
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit,
                    style: AppTypography.bodyMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _defaultFormat(double animatedValue) {
    if (!animatedValue.isFinite) {
      return '--';
    }

    if (animatedValue.abs() >= 100 ||
        animatedValue == animatedValue.roundToDouble()) {
      return animatedValue.toStringAsFixed(0);
    }

    return animatedValue.toStringAsFixed(1);
  }
}
