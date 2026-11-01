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
  static const darkRaised = Color(0xFF221A1B);
  static const darkOutline = Color(0xFF3A2E2F);
  static const darkOnSurface = Color(0xFFF5EFEE);
  static const darkMuted = Color(0xFFA89A98); // 6.4:1 on darkSurface

  static const lightBackground = Color(0xFFFBF8F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFF4EEED);
  static const lightOutline = Color(0xFFE3D8D6);
  static const lightOnSurface = Color(0xFF1A1212);
  static const lightMuted = Color(0xFF6E6260); // 5.9:1 on white
}

/// Colours with a single meaning each, per theme. Read with
/// `Theme.of(context).extension<CrocellTokens>()!` or `context.tokens`.
@immutable
class CrocellTokens extends ThemeExtension<CrocellTokens> {
  const CrocellTokens({
    required this.raised,
    required this.outline,
    required this.muted,
    required this.brandText,
    required this.good,
  });

  /// Cards and grouped rows, one step above the surface.
  final Color raised;

  /// Hairlines and card borders, visible in both themes.
  final Color outline;

  /// Secondary text. ≥4.5:1 on surface and raised.
  final Color muted;

  /// Brand red that is legible as small text: #F08A86 on dark (7.1:1),
  /// #A3201C on light (7.4:1). Primary itself is too light for small text.
  final Color brandText;

  /// "This node works". The one non-brand hue, and never the only signal:
  /// it always comes with an icon and a word.
  final Color good;

  static const dark = CrocellTokens(
    raised: CrocellColors.darkRaised,
    outline: CrocellColors.darkOutline,
    muted: CrocellColors.darkMuted,
    brandText: Color(0xFFF08A86),
    good: Color(0xFF4CC38A), // 7.9:1 on darkSurface
  );

  static const light = CrocellTokens(
    raised: CrocellColors.lightRaised,
    outline: CrocellColors.lightOutline,
    muted: CrocellColors.lightMuted,
    brandText: Color(0xFFA3201C),
    good: Color(0xFF1B7A4F), // 5.4:1 on white
  );

  @override
  CrocellTokens copyWith({Color? raised, Color? outline, Color? muted, Color? brandText, Color? good}) =>
      CrocellTokens(
        raised: raised ?? this.raised,
        outline: outline ?? this.outline,
        muted: muted ?? this.muted,
        brandText: brandText ?? this.brandText,
        good: good ?? this.good,
      );

  @override
  CrocellTokens lerp(CrocellTokens? other, double t) {
    if (other == null) return this;
    return CrocellTokens(
      raised: Color.lerp(raised, other.raised, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      good: Color.lerp(good, other.good, t)!,
    );
  }
}

extension CrocellThemeX on BuildContext {
  CrocellTokens get tokens => Theme.of(this).extension<CrocellTokens>()!;
}

ThemeData crocellTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final tokens = dark ? CrocellTokens.dark : CrocellTokens.light;
  final onSurface = dark ? CrocellColors.darkOnSurface : CrocellColors.lightOnSurface;
  final surface = dark ? CrocellColors.darkSurface : CrocellColors.lightSurface;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: CrocellColors.primary,
    onPrimary: CrocellColors.lightOnSurface, // 5.8:1 on primary
    secondary: CrocellColors.secondary,
    onSecondary: CrocellColors.lightOnSurface,
    tertiary: CrocellColors.accent,
    onTertiary: Colors.white,
    error: dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
    onError: dark ? CrocellColors.lightOnSurface : Colors.white,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: tokens.muted,
    surfaceContainer: tokens.raised,
    surfaceContainerHigh: tokens.raised,
    outline: tokens.outline,
    outlineVariant: tokens.outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? CrocellColors.darkBackground : CrocellColors.lightBackground,
    extensions: [tokens],
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.outline),
      ),
    ),
    dividerTheme: DividerThemeData(color: tokens.outline, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        // Merge into labelLarge: a bare TextStyle would drop the font family.
        textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    // Primary red is 3.6:1 on white, too light for small text: text-coloured
    // controls use brandText in both themes (7.4:1 light, 7.1:1 dark).
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.brandText, minimumSize: const Size(44, 44)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: tokens.brandText,
        selectedBackgroundColor: CrocellColors.accent,
        selectedForegroundColor: Colors.white, // 10.4:1 on accent
        side: BorderSide(color: tokens.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.raised,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CrocellColors.primary, width: 2),
      ),
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
  );
}
