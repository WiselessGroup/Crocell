import 'package:flutter/material.dart';

/// Brand palette. Names match assets/brand and the Obsidian note «Бренд Crocell».
abstract final class CrocellColors {
  /// Deep crimson. Surfaces, glow, the pressed connect button.
  /// Never text on dark backgrounds: ~1.9:1.
  static const accent = Color(0xFF860111);

  /// Main action colour, the "connected" state.
  /// White text on it is ~3.6:1: fine for large bold labels only.
  static const primary = Color(0xFFE9524E);

  /// Magma ochre for secondary accents and charts.
  static const secondary = Color(0xFFD4572A);

  static const darkBackground = Color(0xFF0E0B0B);
  static const darkSurface = Color(0xFF181213);
  static const darkOnSurface = Color(0xFFF5EFEE);
  static const darkMuted = Color(0xFF9C8F8D);

  static const lightBackground = Color(0xFFFBF8F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF1A1212);
  static const lightMuted = Color(0xFF6E6260);
}

ThemeData crocellTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: CrocellColors.primary,
    onPrimary: CrocellColors.lightOnSurface,
    secondary: CrocellColors.secondary,
    onSecondary: CrocellColors.lightOnSurface,
    tertiary: CrocellColors.accent,
    onTertiary: Colors.white,
    error: const Color(0xFFFF6B5E),
    onError: CrocellColors.lightOnSurface,
    surface: dark ? CrocellColors.darkSurface : CrocellColors.lightSurface,
    onSurface: dark ? CrocellColors.darkOnSurface : CrocellColors.lightOnSurface,
    onSurfaceVariant: dark ? CrocellColors.darkMuted : CrocellColors.lightMuted,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? CrocellColors.darkBackground : CrocellColors.lightBackground,
    splashFactory: NoSplash.splashFactory,
    textTheme: Typography.material2021(platform: TargetPlatform.iOS)
        .englishLike
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
  );
}
