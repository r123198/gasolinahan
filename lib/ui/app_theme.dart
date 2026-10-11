import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Brand colour tokens. Use these (or the matching [ColorScheme] roles)
/// instead of raw hex values in widgets. Contrast ratios are against white
/// unless noted.
abstract final class AppColors {
  static const ink = Color(0xFF111827); // primary text + primary buttons
  static const text = Color(0xFF0F172A); // 17.9:1
  static const textMuted = Color(0xFF5F6B7D); // 5.4:1 (5.0:1 on background)
  static const outline = Color(0xFF7C8798); // 3.6:1 — field/control borders
  static const divider = Color(0xFFE2E8F0); // decorative only
  static const background = Color(0xFFF4F6F9);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF1F5F9);

  /// Fills, tints and large shapes only — fails as text on white (2.3:1).
  static const go = Color(0xFF22C55E);

  /// Green for text, icons and filled buttons with white text (5.0:1).
  static const goStrong = Color(0xFF15803D);
  static const goTint = Color(0xFFDCFCE7);
  static const warning = Color(0xFFB45309); // 5.0:1
  static const error = Color(0xFFB91C1C); // 6.5:1
  static const accent = Color(0xFF6D28D9); // 7.1:1 — OCR / offline accents

  // Number roles: one colour per kind of figure so a glance tells you what
  // a number is. Good/bad always ship with an arrow or words, never alone.
  static const distance = Color(0xFF4338CA); // 7.9:1, the logo's indigo
  static const fuel = Color(0xFF0E7490); // 5.4:1, liters
  static const good = goStrong; // cheaper, more km per liter
  static const bad = warning; // pricier, fewer km per liter

  // Same roles on the dark summary card (all ≥ 7:1 on [ink]).
  static const onDarkMuted = Color(0xFFA1A9B8);
  static const onDarkGood = Color(0xFF4ADE80);
  static const onDarkDistance = Color(0xFFA5B4FC);
  static const onDarkFuel = Color(0xFF67E8F9);

  // PH pump colours for fuel grades.
  static const fuelRegular = Color(0xFF1D4ED8);
  static const fuelPremium = Color(0xFFB91C1C);
  static const fuelDiesel = Color(0xFF15803D);
}

class AppTheme {
  static const fontFamily = 'Montserrat';

  static const _textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    ),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.ink,
          onPrimary: Colors.white,
          secondary: AppColors.goStrong,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          onSurfaceVariant: AppColors.textMuted,
          surfaceContainerHighest: AppColors.surfaceMuted,
          outline: AppColors.outline,
          outlineVariant: AppColors.divider,
          error: AppColors.error,
        );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      // Cupertino widgets (iOS) pick up the same brand palette.
      cupertinoOverrideTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(fontFamily: fontFamily, color: AppColors.text),
          actionTextStyle: TextStyle(fontFamily: fontFamily),
          pickerTextStyle: TextStyle(fontFamily: fontFamily),
          tabLabelTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        primaryColor: AppColors.ink,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.background,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme
          .merge(_textTheme)
          .apply(
            fontFamily: fontFamily,
            bodyColor: AppColors.text,
            displayColor: AppColors.text,
          ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        floatingLabelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: border(AppColors.outline),
        enabledBorder: border(AppColors.outline),
        focusedBorder: border(AppColors.ink, 2),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 2),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.textMuted,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        extendedTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.go,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
