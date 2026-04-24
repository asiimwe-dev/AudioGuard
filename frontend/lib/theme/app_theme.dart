import 'package:flutter/material.dart';

/// Material Design 3 themed colors for AudioGuard
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6200EE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color onPrimaryContainer = Color(0xFF21005D);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF03DAC6);
  static const Color onSecondary = Color(0xFF000000);
  static const Color secondaryContainer = Color(0xFFB0F0E8);
  static const Color onSecondaryContainer = Color(0xFF004D47);
  
  // Tertiary Colors
  static const Color tertiary = Color(0xFF03DAC6);
  static const Color onTertiary = Color(0xFF000000);
  
  // Error Colors
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color onErrorContainer = Color(0xFF410E0B);
  
  // Neutral Colors
  static const Color background = Color(0xFFFFFBFE);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color onSurface = Color(0xFF1C1B1F);
  
  // Additional Utility Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);
}

/// Theme configuration for AudioGuard Mobile
class AppTheme {
  /// Light theme data
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          fontFamily: 'Roboto',
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Roboto',
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Roboto',
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          fontFamily: 'Roboto',
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          fontFamily: 'Roboto',
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          fontFamily: 'Roboto',
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.onBackground),
        hintStyle: TextStyle(
          color: AppColors.onBackground.withValues(alpha: 0.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }

  /// Dark theme data
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: Color(0xFF4C2D9F),
        onPrimaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: Color(0xFF003731),
        secondaryContainer: Color(0xFF005048),
        onSecondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: Color(0xFF003731),
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: Color(0xFF601410),
        onErrorContainer: AppColors.errorContainer,
        surface: Color(0xFF0A0A0E),
        onSurface: Color(0xFFE7E0EB),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          fontFamily: 'Roboto',
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          fontFamily: 'Roboto',
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Roboto',
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Roboto',
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          fontFamily: 'Roboto',
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          fontFamily: 'Roboto',
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          fontFamily: 'Roboto',
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: Color(0xFFE7E0EB)),
        hintStyle: TextStyle(
          color: const Color(0xFFE7E0EB).withValues(alpha: 0.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2C2C30),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF1C1B1F),
        foregroundColor: Color(0xFFE7E0EB),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE7E0EB),
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}
