import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const String displayFontFamily = 'Space Grotesk';
  static const String bodyFontFamily = 'Inter';
  static const String monoFontFamily = 'JetBrains Mono';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.05,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 2,
    height: 1.3,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle monoLarge = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static const TextStyle monoMedium = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.15,
  );

  static const TextStyle monoSmall = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static TextTheme textTheme(Color color, Color secondaryColor) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: color),
      headlineMedium: headlineMedium.copyWith(color: color),
      bodyMedium: bodyMedium.copyWith(color: color),
      labelSmall: labelSmall.copyWith(color: secondaryColor),
      titleMedium: bodyMedium.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: monoSmall.copyWith(color: secondaryColor),
    );
  }
}
