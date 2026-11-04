import 'package:flutter/material.dart';

/// Design tokens for the gamified "Trek Tracking" style:
/// near-black background, dark green-grey surfaces, one neon accent.
/// Every colour in the app comes from here (enforced by `tasks/01`).
abstract final class TsColors {
  // Surfaces
  static const bg = Color(0xFF070A07);
  static const surface = Color(0xFF0F150F);
  static const surfaceHigh = Color(0xFF162016);
  static const outline = Color(0xFF1F2B1F);
  static const scrim = Color(0xCC070A07);

  // Accent
  static const neon = Color(0xFF9DFF1E);
  static const neonDeep = Color(0xFF7ED321);
  static const onNeon = Color(0xFF0B130B);

  // Text
  static const textPrimary = Color(0xFFF4F7F2);
  static const textMuted = Color(0xFF8FA08C);

  // Semantic
  static const success = neon;
  static const warning = Color(0xFFFFC53D);
  static const danger = Color(0xFFFF4D4D);
  static const dangerDeep = Color(0xFFB3001B);
  static const info = Color(0xFF3DA5FF);

  // Difficulty
  static const difficultyEasy = neon;
  static const difficultyModerate = warning;
  static const difficultyHard = danger;

  // Digital Rope states
  static const ropeConnected = neon;
  static const ropeWeak = warning;
  static const ropeFallingBehind = Color(0xFFFF8A3D);
  static const ropeSeparated = danger;
  static const ropeCritical = dangerDeep;
  static const selfMarker = info;

  // Backwards-compatible aliases (older screens). Prefer the names above.
  static const primary = neon;
  static const primaryDeep = neonDeep;
  static const green = neon;
  static const amber = warning;
  static const red = danger;
  static const text = textPrimary;
  static const muted = textMuted;
  static const cream = textPrimary;
}

/// Spacing and radius scale.
abstract final class TsSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 18.0;
  static const radiusXl = 24.0;
}

/// Text styles used across the app on top of the Material text theme.
abstract final class TsText {
  static const display = TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5);
  static const h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2);
  static const h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static const bodyStrong = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: TsColors.textMuted);
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6);
  static const stat = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const scheme = ColorScheme.dark(
    primary: TsColors.neon,
    onPrimary: TsColors.onNeon,
    secondary: TsColors.neonDeep,
    onSecondary: TsColors.onNeon,
    surface: TsColors.surface,
    onSurface: TsColors.textPrimary,
    error: TsColors.danger,
    onError: Colors.white,
    outline: TsColors.outline,
    surfaceContainerHighest: TsColors.surfaceHigh,
    surfaceContainer: TsColors.surface,
    tertiary: TsColors.info,
  );
  final radius = BorderRadius.circular(TsSpace.radiusMd);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: TsColors.bg,
    canvasColor: TsColors.bg,
    splashColor: TsColors.neon.withValues(alpha: 0.08),
    highlightColor: TsColors.neon.withValues(alpha: 0.05),
    appBarTheme: const AppBarTheme(
      backgroundColor: TsColors.bg,
      foregroundColor: TsColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TsColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: TsColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TsSpace.radiusLg),
        side: const BorderSide(color: TsColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TsColors.neon,
        foregroundColor: TsColors.onNeon,
        disabledBackgroundColor: TsColors.surfaceHigh,
        disabledForegroundColor: TsColors.textMuted,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TsColors.textPrimary,
        backgroundColor: TsColors.surface,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: TsColors.outline),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TsColors.neon,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: TsColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TsColors.surface,
      hintStyle: const TextStyle(color: TsColors.textMuted),
      labelStyle: const TextStyle(color: TsColors.textMuted),
      prefixIconColor: TsColors.textMuted,
      suffixIconColor: TsColors.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TsColors.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TsColors.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TsColors.neon, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TsColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TsColors.danger, width: 1.5)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: TsColors.surface,
      selectedColor: TsColors.neon,
      disabledColor: TsColors.surface,
      side: const BorderSide(color: TsColors.outline),
      labelStyle: const TextStyle(color: TsColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      secondaryLabelStyle: const TextStyle(color: TsColors.onNeon, fontWeight: FontWeight.w800, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TsColors.surface,
      indicatorColor: TsColors.neon.withValues(alpha: 0.14),
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? TsColors.neon : TsColors.textMuted, size: 24)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? TsColors.neon : TsColors.textMuted)),
    ),
    dividerTheme: const DividerThemeData(color: TsColors.outline, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TsColors.surface,
      modalBackgroundColor: TsColors.surface,
      showDragHandle: true,
      dragHandleColor: TsColors.outline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(TsSpace.radiusXl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TsColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TsSpace.radiusLg)),
      titleTextStyle: TsText.h2.copyWith(color: TsColors.textPrimary),
      contentTextStyle: TsText.body.copyWith(color: TsColors.textPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TsColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: TsColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? TsColors.onNeon : TsColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? TsColors.neon : TsColors.surfaceHigh),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? TsColors.neon : TsColors.outline),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? TsColors.neon : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(TsColors.onNeon),
      side: const BorderSide(color: TsColors.outline, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TsColors.neon,
      linearTrackColor: TsColors.surfaceHigh,
      circularTrackColor: TsColors.surfaceHigh,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: TsColors.textMuted,
      textColor: TsColors.textPrimary,
      subtitleTextStyle: TextStyle(color: TsColors.textMuted, fontSize: 12.5),
    ),
    textTheme: base.textTheme.apply(bodyColor: TsColors.textPrimary, displayColor: TsColors.textPrimary),
  );
}
