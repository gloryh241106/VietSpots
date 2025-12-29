import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryRed = Color(0xFFDC143C);
  static const Color accentYellow = Color(0xFFFFA500);
  static const Color backgroundLight = Color(0xFFF8F5F0);
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color cardDark = Color(0xFF1F1F1F);

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
    textTheme: _safeTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryRed,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primaryRed.withValues(alpha: 0.9), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primaryRed, width: 2),
      ),
      hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
    ),
    // cardTheme intentionally omitted to avoid SDK CardThemeData mismatch; use `cardColor` and `Card` styles locally.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      elevation: 12,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryRed,
      elevation: 6,
    ),
    iconTheme: const IconThemeData(color: primaryRed),
    dividerTheme: DividerThemeData(color: Colors.grey[300], thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[100]!,
      selectedColor: primaryRed.withValues(alpha: 0.12),
      secondarySelectedColor: primaryRed.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    cardColor: cardDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryRed,
      secondary: accentYellow,
      surface: cardDark,
    ),
    textTheme: _safeTextTheme(ThemeData.dark()),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF161616),
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[900],
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primaryRed.withValues(alpha: 0.8), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: primaryRed, width: 2),
      ),
      hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
    ),
    // cardTheme intentionally omitted to avoid SDK CardThemeData mismatch; use `cardColor` and `Card` styles locally.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      elevation: 12,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryRed,
      elevation: 6,
    ),
    iconTheme: const IconThemeData(color: primaryRed),
    dividerTheme: DividerThemeData(color: Colors.grey[800], thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[850]!,
      selectedColor: primaryRed.withValues(alpha: 0.12),
      secondarySelectedColor: primaryRed.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 120),
    ),
  );
}

/// Returns a safe text theme using GoogleFonts `Inter` with sensible defaults.
TextTheme _safeTextTheme([ThemeData? base]) {
  final baseText = base?.textTheme ?? ThemeData.light().textTheme;
  return GoogleFonts.interTextTheme(baseText).copyWith(
    headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800),
    titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
  );
}
