import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sophisticated Palette for "Authority & Trust"
class AppColors {
  static const Color navy = Color(0xFF0F172A);           // Deep Navy (Background)
  static const Color indigo = Color(0xFF6366F1);         // Electric Indigo (Primary)
  static const Color teal = Color(0xFF2DD4BF);           // Verification Teal (Accent)
  static const Color slate = Color(0xFF64748B);          // Secondary Text
  static const Color background = Color(0xFFF8FAFC);     // Light Background
  static const Color surface = Color(0xFFFFFFFF);        // Card Surface
}

/// Theme configuration for AudioGuard Mobile
class AppTheme {
  /// Light theme data
  static ThemeData lightTheme(double fontScale) {
    return _applyFontScale(ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.indigo,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0E7FF),
        onPrimaryContainer: AppColors.navy,
        secondary: AppColors.teal,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFCCFBF1),
        onSecondaryContainer: Color(0xFF0F172A),
        tertiary: AppColors.teal,
        onTertiary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        surface: AppColors.surface,
        onSurface: AppColors.navy,
      ),
      textTheme: _buildTextTheme(fontScale),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    ), fontScale);
  }

  /// Dark theme data
  static ThemeData darkTheme(double fontScale) {
    return _applyFontScale(ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.indigo,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF312E81),
        onPrimaryContainer: Color(0xFFE0E7FF),
        secondary: AppColors.teal,
        onSecondary: AppColors.navy,
        secondaryContainer: Color(0xFF0F172A),
        onSecondaryContainer: Color(0xFFCCFBF1),
        tertiary: AppColors.teal,
        onTertiary: AppColors.navy,
        error: Color(0xFFF87171),
        onError: AppColors.navy,
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: Color(0xFFFEE2E2),
        surface: AppColors.navy,
        onSurface: Color(0xFFF1F5F9),
      ),
      textTheme: _buildTextTheme(fontScale),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ), fontScale);
  }

  static TextTheme _buildTextTheme(double fontScale) {
    return GoogleFonts.robotoFlexTextTheme().copyWith(
      headlineMedium: GoogleFonts.robotoFlex(fontSize: 24 * fontScale, fontWeight: FontWeight.bold),
      titleMedium: GoogleFonts.robotoFlex(fontSize: 16 * fontScale, fontWeight: FontWeight.w600),
      bodyMedium: GoogleFonts.robotoFlex(fontSize: 14 * fontScale, fontWeight: FontWeight.normal),
      labelSmall: GoogleFonts.robotoMono(fontSize: 12 * fontScale, fontWeight: FontWeight.w500, letterSpacing: 1.1),
    );
  }

  static ThemeData _applyFontScale(ThemeData theme, double fontScale) {
    return theme; 
  }
}
