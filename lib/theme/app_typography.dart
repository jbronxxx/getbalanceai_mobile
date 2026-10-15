import 'package:flutter/material.dart';

/// Шкала размеров шрифта приложения там, где роли `TextTheme` не подходят.
///
/// Значения совпадают с прежними числами в виджетах; новый текст задавайте
/// через `TextTheme`, а эти размеры — только для уже принятых ролей.
abstract final class AppFontSize {
  /// Подписи под суммами, мелкие пояснения.
  static const double micro = 10;

  /// Подписи легенды диаграммы.
  static const double legend = 10.5;

  /// Подписи навбара, бейджи, вторичные строки.
  static const double small = 11;

  /// Ошибки полей, подсказки, тост с заголовком.
  static const double caption = 12;

  /// Текст тоста с заголовком.
  static const double toastWithTitle = 12.5;

  /// Пояснения в диалогах.
  static const double hint = 13;

  /// Текст тоста без заголовка.
  static const double toastSingle = 13.5;

  /// Основной текст диалогов и тостов.
  static const double body = 14;

  /// Кнопки диалогов.
  static const double button = 15;

  /// Крупные кнопки.
  static const double lead = 16;

  /// Заголовки экранов и листов.
  static const double title = 18;

  /// Заголовки диалогов, крупные числа в карточках.
  static const double headline = 20;
}

/// Повторяющиеся стили текста.
abstract final class AppTypography {
  /// Заголовок экрана в стеклянной шапке и заголовки листов.
  static TextStyle? screenTitle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: AppFontSize.title,
      color: theme.colorScheme.onSurface,
    );
  }
}
