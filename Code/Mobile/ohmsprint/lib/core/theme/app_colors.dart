import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color surfaceDim = Color(0xFF111125);
  static const Color surfaceContainerLow = Color(0xFF1A1A2E);
  static const Color surfaceContainer = Color(0xFF1E1E32);
  static const Color surfaceContainerHigh = Color(0xFF28283D);
  static const Color surfaceContainerHighest = Color(0xFF333348);
  static const Color surfaceBright = Color(0xFF37374D);

  static const Color onSurface = Color(0xFFE2E0FC);
  static const Color onSurfaceVariant = Color(0xFFBFC7D4);
  static const Color outlineVariant = Color(0xFF404752);

  static const Color primary = Color(0xFF9ECAFF);
  static const Color error = Color(0xFFFFB4AB);
  static const Color secondary = Color(0xFF78DC77);
  static const Color tertiary = Color(0xFFFFB870);

  static const Color lightScaffold = Color(0xFFF5F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFE8ECF4);
  static const Color lightSurfaceContainerHigh = Color(0xFFDDE4EF);
  static const Color lightOnSurface = Color(0xFF171C24);
  static const Color lightOnSurfaceVariant = Color(0xFF5E6878);

  static const Color voltage = primary;
  static const Color current = error;
  static const Color power = secondary;
  static const Color frequency = tertiary;
  static const Color energy = secondary;
  static const Color powerFactor = secondary;

  static Color get primaryGlow => primary.withValues(alpha: 0.4);
  static Color get errorGlow => error.withValues(alpha: 0.4);
  static Color get secondaryGlow => secondary.withValues(alpha: 0.4);
  static Color get tertiaryGlow => tertiary.withValues(alpha: 0.4);
  static Color get voltageGlow => voltage.withValues(alpha: 0.4);
  static Color get currentGlow => current.withValues(alpha: 0.4);
  static Color get powerGlow => power.withValues(alpha: 0.4);
  static Color get frequencyGlow => frequency.withValues(alpha: 0.4);
}
