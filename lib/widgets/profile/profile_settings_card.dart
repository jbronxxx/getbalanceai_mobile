import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';
import '../../utils/utils.dart';
import 'currency_picker_sheet.dart';
import 'language_picker_sheet.dart';
import 'theme_mode_picker_sheet.dart';
import '../../theme/app_colors.dart';

/// Карточка настроек интерфейса (тема, язык, валюта).
class ProfileSettingsCard extends StatelessWidget {
  final VoidCallback onLanguageChanged;

  const ProfileSettingsCard({
    super.key,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    final glassBg = AppColors.of(context).cardGlassBackground;
    final glassBorder = AppColors.of(context).cardBorder;
    final dividerColor = AppColors.of(context).cardDivider;

    return Container(
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: glassBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              l10n.theme_mode,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: PreferencesService.instance.themeModeNotifier,
              builder: (context, mode, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ThemeModePickerSheet.getThemeModeLabel(context, mode),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.of(context).accentText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 20, color: colorScheme.outline),
                  ],
                );
              },
            ),
            onTap: () => ThemeModePickerSheet.show(context),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          ListTile(
            title: Text(
              l10n.language,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LanguageManager.currentLanguage.displayName,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.of(context).accentText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: colorScheme.outline),
              ],
            ),
            onTap: () {
              LanguagePickerSheet.show(
                context,
                onLanguageChanged: onLanguageChanged,
              );
            },
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          ListTile(
            title: Text(
              l10n.currency,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: ValueListenableBuilder<Currency>(
              valueListenable: CurrencyFormatter.currencyNotifier,
              builder: (context, currency, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency.localizedName,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.of(context).accentText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 20, color: colorScheme.outline),
                  ],
                );
              },
            ),
            onTap: () => CurrencyPickerSheet.show(context),
          ),
        ],
      ),
    );
  }
}
