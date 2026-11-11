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

  /// Строки из контекста, а вне дерева локализации — текущего языка.
  static AppLocalizations _l10n(BuildContext context) =>
      AppLocalizations.of(context) ?? LanguageManager.l10n;

  static String getThemeTitle(BuildContext context) =>
      _l10n(context).theme_mode;

  static String getThemeModeLabel(BuildContext context, ThemeMode mode) {
    final l = _l10n(context);
    return switch (mode) {
      ThemeMode.system => l.theme_system,
      ThemeMode.light => l.theme_light,
      ThemeMode.dark => l.theme_dark,
    };
  }

  /// Иконка режима темы для пункта списка.
  static IconData iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final currentMode = PreferencesService.instance.themeModeNotifier.value;
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
                  key: ValueKey('theme_mode_${mode.name}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    iconFor(mode),
                    color: isSelected ? accent : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? accent : colorScheme.onSurface,
                    ),
                  ),
                  trailing:
                      isSelected ? Icon(Icons.check, color: accent) : null,
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
      ),
    );
  }
}
