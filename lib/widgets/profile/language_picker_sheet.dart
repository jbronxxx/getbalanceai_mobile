import 'package:flutter/material.dart';
import '../../utils/utils.dart';

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
      backgroundColor: Colors.transparent,
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
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: colorScheme.primary)
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
