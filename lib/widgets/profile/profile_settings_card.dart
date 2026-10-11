import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';
import '../../utils/utils.dart';
import 'currency_picker_sheet.dart';
import 'language_picker_sheet.dart';

/// Карточка настроек интерфейса (тема, язык, валюта, уведомления).
class ProfileSettingsCard extends StatefulWidget {
  final VoidCallback onLanguageChanged;

  const ProfileSettingsCard({
    super.key,
    required this.onLanguageChanged,
  });

  @override
  State<ProfileSettingsCard> createState() => _ProfileSettingsCardState();
}

class _ProfileSettingsCardState extends State<ProfileSettingsCard> {
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications =
        await PreferencesService.instance.getNotificationsEnabled();
    final darkMode = await PreferencesService.instance.getDarkMode();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _isDarkMode = darkMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              l10n.dark_mode,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            value: _isDarkMode,
            activeColor: colorScheme.primary,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              PreferencesService.instance.saveDarkMode(val);
            },
          ),
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
                    color: colorScheme.primary,
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
                onLanguageChanged: widget.onLanguageChanged,
              );
            },
          ),
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
                        color: colorScheme.primary,
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
          SwitchListTile(
            title: Text(
              l10n.notifications,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            value: _notificationsEnabled,
            activeColor: colorScheme.primary,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              PreferencesService.instance.saveNotificationsEnabled(val);
            },
          ),
        ],
      ),
    );
  }
}
