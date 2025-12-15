import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    textTheme: GoogleFonts.notoSansTextTheme(),
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
    textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
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
  );
}
