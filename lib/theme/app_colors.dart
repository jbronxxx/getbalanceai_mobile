import 'package:flutter/material.dart';

/// Семантические цвета приложения сверх `ColorScheme`: фоны экранов и листов,
/// карточки, фирменная бирюзовая карточка, предупреждения бюджета.
///
/// Значения — те, что раньше были константами в виджетах; использовать через
/// `AppColors.of(context)`, а не `Color(0x...)` в экранах.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Фон каркаса и экранов-вкладок (под стеклянной шапкой).
  final Color shellBackground;

  /// Фон модальных листов (формы, выбор валюты/языка/темы).
  final Color sheetBackground;

  /// Контур модальных листов.
  final Color sheetBorder;

  /// Тень модальных листов.
  final Color sheetShadow;

  /// «Ручка» листа в тёмной теме (в светлой — `outlineVariant` схемы).
  final Color sheetHandleDark;

  /// Непрозрачный фон карточек и строк (под ним — подложка свайп-удаления).
  final Color cardBackground;

  /// Полупрозрачный фон «стеклянных» карточек (профиль, советы AI).
  final Color cardGlassBackground;

  /// Контур карточек.
  final Color cardBorder;

  /// Разделители внутри карточек.
  final Color cardDivider;

  /// Мягкая тень карточек.
  final Color cardShadow;

  /// Непрозрачная заливка стекла, когда размытие не поддерживается.
  final Color glassFallbackStart;
  final Color glassFallbackEnd;

  /// Фон полей и контейнеров без размытия.
  final Color fieldBackground;

  /// Фон выпадающих списков.
  final Color dropdownBackground;

  /// Плавающая плашка индикатора pull-to-refresh.
  final Color pillBackground;

  /// Бирюзовый текст и иконки: в тёмной теме светлее `primary`, чтобы
  /// контраст на тёмных фонах был не ниже WCAG AA (4.5:1).
  final Color accentText;

  /// Фирменная бирюзовая карточка (баланс, бюджет месяца): градиент и тень.
  final Color brandGradientStart;
  final Color brandGradientEnd;
  final Color brandShadow;

  /// Текст и элементы на фирменной карточке.
  final Color onBrand;

  /// Предупреждение: 75–100% лимита.
  final Color warning;

  /// Перерасход лимита (мягкий оранжевый вместо пугающего красного).
  final Color exceeded;

  /// Перерасход на фирменной карточке.
  final Color exceededOnBrand;

  /// Бейдж «расходы больше дохода» на фирменной карточке и его текст.
  final Color overspendBadge;
  final Color onOverspendBadge;

  /// Кнопки входа: Google — светлая, Apple — тёмная (по правилам брендов).
  final Color googleButtonBackground;
  final Color googleButtonText;
  final Color appleButtonBackground;

  const AppColors({
    required this.shellBackground,
    required this.sheetBackground,
    required this.sheetBorder,
    required this.sheetShadow,
    required this.sheetHandleDark,
    required this.cardBackground,
    required this.cardGlassBackground,
    required this.cardBorder,
    required this.cardDivider,
    required this.cardShadow,
    required this.glassFallbackStart,
    required this.glassFallbackEnd,
    required this.fieldBackground,
    required this.dropdownBackground,
    required this.pillBackground,
    required this.accentText,
    required this.brandGradientStart,
    required this.brandGradientEnd,
    required this.brandShadow,
    required this.onBrand,
    required this.warning,
    required this.exceeded,
    required this.exceededOnBrand,
    required this.overspendBadge,
    required this.onOverspendBadge,
    required this.googleButtonBackground,
    required this.googleButtonText,
    required this.appleButtonBackground,
  });

  /// Нейтральные основы для наложений, не зависящие от темы:
  /// прозрачность, тени и затемнения, блики и контуры стекла.
  static const Color transparent = Color(0x00000000);
  static const Color shadowBase = Color(0xFF000000);
  static const Color highlightBase = Color(0xFFFFFFFF);

  /// Текст и элементы на фирменной бирюзовой карточке (в обеих темах).
  static const Color onBrandBase = Color(0xFFFFFFFF);

  /// Акценты направлений «Доход» / «Расход» на фирменной карточке:
  /// мятно-зелёный и мягкий коралловый.
  static const Color incomeOnBrand = Color(0xFF6EE7B7);
  static const Color expenseOnBrand = Color(0xFFFCA5A5);

  static const _brandStart = Color(0xFF0F766E);
  static const _brandEnd = Color(0xFF115E59);

  static const light = AppColors(
    shellBackground: Color(0xFFEFF2F6),
    sheetBackground: Color(0xFFF8FAFC),
    sheetBorder: Color(0x14000000),
    sheetShadow: Color(0x1A000000),
    sheetHandleDark: Color(0x40FFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    cardGlassBackground: Color(0xD9FFFFFF),
    cardBorder: Color(0xFFE2E8F0),
    cardDivider: Color(0xFFF1F5F9),
    cardShadow: Color(0x0A000000),
    glassFallbackStart: Color(0xDDFFFFFF),
    glassFallbackEnd: Color(0xDDF1F5F9),
    fieldBackground: Color(0xFFFFFFFF),
    dropdownBackground: Color(0xFFFFFFFF),
    pillBackground: Color(0xF0FFFFFF),
    accentText: _brandStart,
    brandGradientStart: _brandStart,
    brandGradientEnd: _brandEnd,
    brandShadow: Color(0x290F766E),
    onBrand: onBrandBase,
    // Темнее исходных #D97706/#EA7A35: текст на белом — не ниже WCAG AA 4.5:1
    warning: Color(0xFFB45309),
    exceeded: Color(0xFFC2410C),
    exceededOnBrand: Color(0xFFFDBA74),
    overspendBadge: Color(0x47F43F5E),
    onOverspendBadge: Color(0xFFFFE4E6),
    googleButtonBackground: Color(0xE0FFFFFF),
    googleButtonText: Color(0xFF0F172A),
    appleButtonBackground: Color(0xF209090B),
  );

  static const dark = AppColors(
    shellBackground: Color(0xFF09090B),
    sheetBackground: Color(0xFF161618),
    sheetBorder: Color(0x2EFFFFFF),
    sheetShadow: Color(0xA6000000),
    sheetHandleDark: Color(0x40FFFFFF),
    cardBackground: Color(0xFF141416),
    cardGlassBackground: Color(0xB3141416),
    cardBorder: Color(0x1FFFFFFF),
    cardDivider: Color(0x14FFFFFF),
    cardShadow: Color(0x38000000),
    glassFallbackStart: Color(0xDD18181C),
    glassFallbackEnd: Color(0xDD121216),
    fieldBackground: Color(0xFF18181C),
    dropdownBackground: Color(0xFF1E1E22),
    pillBackground: Color(0xEB1E293B),
    accentText: Color(0xFF2DD4BF),
    brandGradientStart: _brandStart,
    brandGradientEnd: _brandEnd,
    brandShadow: Color(0x290F766E),
    onBrand: onBrandBase,
    warning: Color(0xFFFCD34D),
    exceeded: Color(0xFFF59E0B),
    exceededOnBrand: Color(0xFFFDBA74),
    overspendBadge: Color(0x47F43F5E),
    onOverspendBadge: Color(0xFFFFE4E6),
    googleButtonBackground: Color(0xD9141416),
    googleButtonText: Color(0xFFFFFFFF),
    appleButtonBackground: Color(0xE618181B),
  );

  /// Цвета текущей темы; без расширения (изолированные тесты) — по яркости.
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Градиент фирменной карточки.
  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandGradientStart, brandGradientEnd],
      );

  @override
  AppColors copyWith({
    Color? shellBackground,
    Color? sheetBackground,
    Color? sheetBorder,
    Color? sheetShadow,
    Color? sheetHandleDark,
    Color? cardBackground,
    Color? cardGlassBackground,
    Color? cardBorder,
    Color? cardDivider,
    Color? cardShadow,
    Color? glassFallbackStart,
    Color? glassFallbackEnd,
    Color? fieldBackground,
    Color? dropdownBackground,
    Color? pillBackground,
    Color? accentText,
    Color? brandGradientStart,
    Color? brandGradientEnd,
    Color? brandShadow,
    Color? onBrand,
    Color? warning,
    Color? exceeded,
    Color? exceededOnBrand,
    Color? overspendBadge,
    Color? onOverspendBadge,
    Color? googleButtonBackground,
    Color? googleButtonText,
    Color? appleButtonBackground,
  }) {
    return AppColors(
      shellBackground: shellBackground ?? this.shellBackground,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      sheetBorder: sheetBorder ?? this.sheetBorder,
      sheetShadow: sheetShadow ?? this.sheetShadow,
      sheetHandleDark: sheetHandleDark ?? this.sheetHandleDark,
      cardBackground: cardBackground ?? this.cardBackground,
      cardGlassBackground: cardGlassBackground ?? this.cardGlassBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      cardDivider: cardDivider ?? this.cardDivider,
      cardShadow: cardShadow ?? this.cardShadow,
      glassFallbackStart: glassFallbackStart ?? this.glassFallbackStart,
      glassFallbackEnd: glassFallbackEnd ?? this.glassFallbackEnd,
      fieldBackground: fieldBackground ?? this.fieldBackground,
      dropdownBackground: dropdownBackground ?? this.dropdownBackground,
      pillBackground: pillBackground ?? this.pillBackground,
      accentText: accentText ?? this.accentText,
      brandGradientStart: brandGradientStart ?? this.brandGradientStart,
      brandGradientEnd: brandGradientEnd ?? this.brandGradientEnd,
      brandShadow: brandShadow ?? this.brandShadow,
      onBrand: onBrand ?? this.onBrand,
      warning: warning ?? this.warning,
      exceeded: exceeded ?? this.exceeded,
      exceededOnBrand: exceededOnBrand ?? this.exceededOnBrand,
      overspendBadge: overspendBadge ?? this.overspendBadge,
      onOverspendBadge: onOverspendBadge ?? this.onOverspendBadge,
      googleButtonBackground:
          googleButtonBackground ?? this.googleButtonBackground,
      googleButtonText: googleButtonText ?? this.googleButtonText,
      appleButtonBackground:
          appleButtonBackground ?? this.appleButtonBackground,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      shellBackground: mix(shellBackground, other.shellBackground),
      sheetBackground: mix(sheetBackground, other.sheetBackground),
      sheetBorder: mix(sheetBorder, other.sheetBorder),
      sheetShadow: mix(sheetShadow, other.sheetShadow),
      sheetHandleDark: mix(sheetHandleDark, other.sheetHandleDark),
      cardBackground: mix(cardBackground, other.cardBackground),
      cardGlassBackground: mix(cardGlassBackground, other.cardGlassBackground),
      cardBorder: mix(cardBorder, other.cardBorder),
      cardDivider: mix(cardDivider, other.cardDivider),
      cardShadow: mix(cardShadow, other.cardShadow),
      glassFallbackStart: mix(glassFallbackStart, other.glassFallbackStart),
      glassFallbackEnd: mix(glassFallbackEnd, other.glassFallbackEnd),
      fieldBackground: mix(fieldBackground, other.fieldBackground),
      dropdownBackground: mix(dropdownBackground, other.dropdownBackground),
      pillBackground: mix(pillBackground, other.pillBackground),
      accentText: mix(accentText, other.accentText),
      brandGradientStart: mix(brandGradientStart, other.brandGradientStart),
      brandGradientEnd: mix(brandGradientEnd, other.brandGradientEnd),
      brandShadow: mix(brandShadow, other.brandShadow),
      onBrand: mix(onBrand, other.onBrand),
      warning: mix(warning, other.warning),
      exceeded: mix(exceeded, other.exceeded),
      exceededOnBrand: mix(exceededOnBrand, other.exceededOnBrand),
      overspendBadge: mix(overspendBadge, other.overspendBadge),
      onOverspendBadge: mix(onOverspendBadge, other.onOverspendBadge),
      googleButtonBackground:
          mix(googleButtonBackground, other.googleButtonBackground),
      googleButtonText: mix(googleButtonText, other.googleButtonText),
      appleButtonBackground:
          mix(appleButtonBackground, other.appleButtonBackground),
    );
  }
}
