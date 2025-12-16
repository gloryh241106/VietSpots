import 'package:flutter/material.dart';

/// Design System - Typography Tokens (Updated for 10/10 UI)
/// Standardized text styles for consistent UI across the app
class AppTypography {
  // Headings - For major sections and titles
  static const heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static const heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: -0.25,
  );

  static const heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  // Section Headers - For content grouping
  static const sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.15,
  );

  // Title Styles - For card titles, list items
  static const titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  // Body Styles - For main content, descriptions
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Label Styles - For buttons, chips, captions
  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
  );

  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Caption Styles - For timestamps, metadata
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static const captionSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0.4,
  );
}

/// Spacing tokens using 8px grid system
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Color tokens for text with proper contrast ratios (WCAG AA compliant)
class AppTextColors {
  // Dark Mode Colors (on #121212 background)
  static const darkPrimary = Colors.white; // Primary text
  static const darkSecondary = Color(0xFFB0B0B0); // Updated for better contrast
  static const darkTertiary = Color(
    0xFF808080,
  ); // Tertiary text, disabled state

  // Light Mode Colors (on white background)
  static const lightPrimary = Color(0xFF212121); // grey[900] - Primary text
  static const lightSecondary = Color(0xFF616161); // grey[700] - Secondary text
  static const lightTertiary = Color(0xFF9E9E9E); // grey[500] - Tertiary text

  /// Get primary text color based on theme brightness
  static Color primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary
        : lightPrimary;
  }

  /// Get secondary text color based on theme brightness (WCAG AA compliant)
  static Color secondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSecondary
        : lightSecondary;
  }

  /// Get tertiary text color based on theme brightness
  static Color tertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTertiary
        : lightTertiary;
  }
}
