import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Централизованная конфигурация тем оформления приложения (Material Design 3).
class AppTheme {
  AppTheme._();

  // Основная цветовая палитра
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color secondaryTeal = Color(0xFF115E59);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningAmber = Color(0xFFD97706);

  // Цвета светлой темы
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightCardBg = Colors.white;
  static const Color lightCardBorder = Color(0xFFF1F5F9);

  // Цвета темной темы (глубокий нейтральный черный)
  static const Color darkSurface = Color(0xFF09090B);
  static const Color darkCardBg = Color(0xFF141416);
  static const Color darkCardBorder = Color(0xFF27272A);

  /// Конфигурация светлой темы Material Design 3.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // InkSparkle (по умолчанию M3 на Android) оставляет зернистую рябь
      // при касании строк в начале скролла.
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: lightSurface,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF475569),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
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
      extensions: const [GlassTheme.light, AppColors.light],
    );
  }

  /// Конфигурация темной темы Material Design 3.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      // InkSparkle (по умолчанию M3 на Android) оставляет зернистую рябь
      // при касании строк в начале скролла.
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: darkSurface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.dark,
        surface: darkSurface,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF27272A),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF18181B),
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF94A3B8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF18181C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
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
      extensions: const [GlassTheme.dark, AppColors.dark],
    );
  }
}

/// Расширение темы Material 3 с токенами эффекта Liquid Glass.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  /// Полупрозрачный цвет поверхности стекла.
  final Color surface;

  /// Цвет завершения градиента поверхности стекла.
  final Color surfaceEnd;

  /// Цвет световой фаски (границы / rim).
  final Color rim;

  /// Цвет рассеянной тени стекла.
  final Color shadow;

  /// Акцентный цвет интерактивных элементов стекла.
  final Color accent;

  /// Цвет фона активного элемента на стекле.
  final Color activeItemBg;

  /// Цвет неактивного содержимого (обеспечивает WCAG AA контраст > 4.5:1).
  final Color inactiveItemColor;

  /// Фон модальных окон и тостов.
  final Color toastSurface;

  /// Граница модальных окон и тостов.
  final Color toastRim;

  /// Базовый радиус размытия заднего плана.
  final double blurSigma;

  const GlassTheme({
    required this.surface,
    required this.surfaceEnd,
    required this.rim,
    required this.shadow,
    required this.accent,
    required this.activeItemBg,
    required this.inactiveItemColor,
    required this.toastSurface,
    required this.toastRim,
    this.blurSigma = 18.0,
  });

  /// Токены Liquid Glass для светлой темы.
  static const light = GlassTheme(
    surface: Color(0xC0FFFFFF),
    surfaceEnd: Color(0xB3F8FAFC),
    rim: Color(0x99CBD5E1),
    shadow: Color(0x14000000),
    accent: AppTheme.primaryTeal,
    activeItemBg: Color(0x1A0F766E),
    inactiveItemColor: Color(0xB3334155),
    toastSurface: Color(0xE0FFFFFF),
    // Граница тоста и диалога: контраст ≥ 3:1 к стеклу и к фону экрана
    toastRim: Color(0xFF7C8BA1),
    blurSigma: 18.0,
  );

  /// Токены Liquid Glass для темной темы.
  static const dark = GlassTheme(
    surface: Color(0xA6141418),
    surfaceEnd: Color(0xB309090D),
    rim: Color(0x24FFFFFF),
    shadow: Color(0x66000000),
    accent: Color(0xFF2DD4BF),
    activeItemBg: Color(0x1FFFFFFF),
    inactiveItemColor: Color(0xB394A3B8),
    toastSurface: Color(0xE0141416),
    toastRim: Color(0x66FFFFFF),
    blurSigma: 18.0,
  );

  /// Получение токенов GlassTheme с безопасным fallback-значением по яркости темы.
  static GlassTheme of(BuildContext context) {
    return Theme.of(context).extension<GlassTheme>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  GlassTheme copyWith({
    Color? surface,
    Color? surfaceEnd,
    Color? rim,
    Color? shadow,
    Color? accent,
    Color? activeItemBg,
    Color? inactiveItemColor,
    Color? toastSurface,
    Color? toastRim,
    double? blurSigma,
  }) {
    return GlassTheme(
      surface: surface ?? this.surface,
      surfaceEnd: surfaceEnd ?? this.surfaceEnd,
      rim: rim ?? this.rim,
      shadow: shadow ?? this.shadow,
      accent: accent ?? this.accent,
      activeItemBg: activeItemBg ?? this.activeItemBg,
      inactiveItemColor: inactiveItemColor ?? this.inactiveItemColor,
      toastSurface: toastSurface ?? this.toastSurface,
      toastRim: toastRim ?? this.toastRim,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceEnd: Color.lerp(surfaceEnd, other.surfaceEnd, t)!,
      rim: Color.lerp(rim, other.rim, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      activeItemBg: Color.lerp(activeItemBg, other.activeItemBg, t)!,
      inactiveItemColor:
          Color.lerp(inactiveItemColor, other.inactiveItemColor, t)!,
      toastSurface: Color.lerp(toastSurface, other.toastSurface, t)!,
      toastRim: Color.lerp(toastRim, other.toastRim, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
    );
  }
}
