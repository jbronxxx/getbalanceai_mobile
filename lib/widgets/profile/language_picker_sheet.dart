import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../../theme/app_colors.dart';

/// Модальный лист выбора языка интерфейса приложения.
class LanguagePickerSheet extends StatelessWidget {
  final VoidCallback? onLanguageChanged;

  const LanguagePickerSheet({
    super.key,
    this.onLanguageChanged,
  });

  static Future<void> show(BuildContext context,
      {VoidCallback? onLanguageChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => LanguagePickerSheet(onLanguageChanged: onLanguageChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

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
              context.l10n.select_language,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...AppLanguage.values.map((lang) {
              final isSelected = LanguageManager.currentLanguage == lang;
              final label = lang.displayName;

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
                  LanguageManager.setLanguage(lang);
                  Navigator.pop(context);
                  onLanguageChanged?.call();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
