import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_sheet.dart';
import 'whole_words_text.dart';

/// Вариант в [AppOptionsSheet].
class AppSheetOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool selected;

  const AppSheetOption({
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
  });
}

/// Шторка выбора одного варианта из списка — в стиле выбора темы, языка
/// и валюты: заголовок, строки с иконкой, выбранная — с галочкой.
class AppOptionsSheet<T> extends StatelessWidget {
  final String title;
  final List<AppSheetOption<T>> options;

  const AppOptionsSheet({
    super.key,
    required this.title,
    required this.options,
  });

  /// Открывает шторку; возвращает выбранное значение или `null` — закрыта.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<AppSheetOption<T>> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => AppOptionsSheet<T>(title: title, options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accent = AppColors.of(context).accentText;

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              WholeWordsText(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              for (final (index, option) in options.indexed)
                ListTile(
                  key: ValueKey('app_option_$index'),
                  contentPadding: EdgeInsets.zero,
                  leading: option.icon == null
                      ? null
                      : Icon(
                          option.icon,
                          color: option.selected
                              ? accent
                              : colorScheme.onSurfaceVariant,
                        ),
                  title: WholeWordsText(
                    option.label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          option.selected ? FontWeight.bold : FontWeight.normal,
                      color: option.selected ? accent : colorScheme.onSurface,
                    ),
                  ),
                  trailing:
                      option.selected ? Icon(Icons.check, color: accent) : null,
                  onTap: () => Navigator.pop(context, option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
