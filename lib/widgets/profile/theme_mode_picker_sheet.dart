import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../../theme/app_colors.dart';

/// Модальный лист выбора темы оформления приложения (дропдаун).
class ThemeModePickerSheet extends StatelessWidget {
  final VoidCallback? onThemeChanged;

  const ThemeModePickerSheet({
    super.key,
    this.onThemeChanged,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onThemeChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => ThemeModePickerSheet(onThemeChanged: onThemeChanged),
    );
  }

  static String getThemeTitle(BuildContext context) {
    try {
      return context.l10n.theme_mode;
    } catch (_) {
      try {
        return LanguageManager.l10n.theme_mode;
      } catch (_) {
        return 'Тема оформления';
      }
    }
  }

  static String getThemeModeLabel(BuildContext context, ThemeMode mode) {
    try {
      final l = context.l10n;
      switch (mode) {
        case ThemeMode.system:
          return l.theme_system;
        case ThemeMode.light:
          return l.theme_light;
        case ThemeMode.dark:
          return l.theme_dark;
      }
    } catch (_) {
      try {
        final l = LanguageManager.l10n;
        switch (mode) {
          case ThemeMode.system:
            return l.theme_system;
          case ThemeMode.light:
            return l.theme_light;
          case ThemeMode.dark:
            return l.theme_dark;
        }
      } catch (_) {
        switch (mode) {
          case ThemeMode.system:
            return 'Системная';
          case ThemeMode.light:
            return 'Светлая';
          case ThemeMode.dark:
            return 'Темная';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final currentMode = PreferencesService.instance.themeModeNotifier.value;

    return Container(
      padding: EdgeInsets.only(
        top: 10,
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: AppSheet.decoration(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SheetHandle(),
            ),
            Text(
              getThemeTitle(context),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...ThemeMode.values.map((mode) {
              final isSelected = currentMode == mode;
              final label = getThemeModeLabel(context, mode);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.of(context).accentText
                        : colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppColors.of(context).accentText)
                    : null,
                onTap: () {
                  PreferencesService.instance.saveThemeMode(mode);
                  Navigator.pop(context);
                  onThemeChanged?.call();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
