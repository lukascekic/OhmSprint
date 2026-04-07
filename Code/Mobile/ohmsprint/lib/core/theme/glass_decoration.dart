import 'package:flutter/material.dart';

import 'app_colors.dart';

class GlassDecoration {
  const GlassDecoration._();

  static BoxDecoration card() {
    return BoxDecoration(
      color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.1),
        width: 0.5,
      ),
    );
  }

  static BoxDecoration elevated() {
    return BoxDecoration(
      color: AppColors.surfaceContainer.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.12),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryGlow.withValues(alpha: 0.25),
          blurRadius: 20,
          spreadRadius: 1,
          blurStyle: BlurStyle.inner,
        ),
        const BoxShadow(
          color: Color(0x66111125),
          blurRadius: 24,
          offset: Offset(0, 16),
        ),
      ],
    );
  }

  static BoxDecoration surface() {
    return BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.outlineVariant.withValues(alpha: 0.15),
        width: 0.5,
      ),
    );
  }
}
