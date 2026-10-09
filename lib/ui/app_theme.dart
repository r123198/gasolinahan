import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const fontFamily = 'Inter';

  static ThemeData light() {
    const seed = Color(0xFF111827); // charcoal
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF111827),
          secondary: const Color(0xFF22C55E), // "go" green accent
          surface: const Color(0xFFF8FAFC),
          surfaceContainerHighest: const Color(0xFFF1F5F9),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      // Cupertino widgets (iOS) pick up the same brand palette.
      cupertinoOverrideTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(fontFamily: fontFamily),
          actionTextStyle: TextStyle(fontFamily: fontFamily),
          pickerTextStyle: TextStyle(fontFamily: fontFamily),
          tabLabelTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        primaryColor: Color(0xFF111827),
        scaffoldBackgroundColor: Color(0xFFF4F6F9),
        barBackgroundColor: Color(0xFFF4F6F9),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
