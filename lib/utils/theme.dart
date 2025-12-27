import 'package:flutter/material.dart';
// Avoid importing google_fonts at app startup to prevent AssetManifest errors.

class AppTheme {
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color backgroundLight = Color(0xFFFFF5F5); // Soft red tint
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF252525); // Improved contrast

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryRed,
    scaffoldBackgroundColor: backgroundLight,
    cardColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: primaryRed,
      secondary: accentYellow,
      surface: Colors.white,
    ),
    // Noto Sans has much better glyph coverage for multi-language UI.
    textTheme: _safeTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryRed,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 120),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryRed,
    scaffoldBackgroundColor: backgroundDark,
    cardColor: cardDark, // Updated for better contrast
    colorScheme: const ColorScheme.dark(
      primary: primaryRed,
      secondary: accentYellow,
      surface: cardDark,
    ),
    textTheme: _safeTextTheme(ThemeData.dark()),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 120),
    ),
  );
}

/// Returns a safe text theme, falling back to default if GoogleFonts fails.
TextTheme _safeTextTheme([ThemeData? base]) {
  // Don't attempt to load external font assets during Theme construction.
  // Return the provided base textTheme or a default one.
  return base?.textTheme ?? ThemeData.light().textTheme;
}
