import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class MetricLabel extends StatelessWidget {
  const MetricLabel(
    this.label, {
    super.key,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      textAlign: textAlign,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 2,
      ),
    );
  }
}
