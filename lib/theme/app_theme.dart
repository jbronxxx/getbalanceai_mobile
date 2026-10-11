import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Централизованная конфигурация тем оформления приложения (Material Design 3).
class AppTheme {
  AppTheme._();

  // Основная цветовая палитра
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color secondaryTeal = Color(0xFF14B8A6);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningAmber = Color(0xFFD97706);

  // Цвета светлой темы
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightCardBg = Colors.white;
  static const Color lightCardBorder = Color(0xFFF1F5F9);

  // Цвета темной темы
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155);

  /// Конфигурация светлой темы Material Design 3.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: secondaryTeal,
        surface: lightSurface,
        error: errorRed,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
        color: lightCardBg,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: primaryTeal, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        errorStyle: const TextStyle(
          color: errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 2,
      ),
    );
  }

  /// Конфигурация темной темы Material Design 3.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.dark,
        primary: primaryTeal,
        secondary: secondaryTeal,
        error: errorRed,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
        color: darkCardBg,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkCardBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: secondaryTeal, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        errorStyle: const TextStyle(
          color: errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 2,
      ),
    );
  }
}
