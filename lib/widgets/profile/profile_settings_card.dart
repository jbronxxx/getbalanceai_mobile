import 'package:flutter/material.dart';
import '../../services/app_lock_service.dart';
import '../../services/preferences_service.dart';
import '../app_alerts.dart';
import '../../utils/utils.dart';
import 'currency_picker_sheet.dart';
import 'language_picker_sheet.dart';
import 'theme_mode_picker_sheet.dart';
import '../one_line_label.dart';
import '../whole_words_text.dart';
import '../../theme/app_colors.dart';

/// Карточка настроек: тема, язык, валюта и блокировка приложения.
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
            title: WholeWordsText(
              l10n.theme_mode,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: PreferencesService.instance.themeModeNotifier,
              builder: (context, mode, child) {
                return _SettingValue(
                    ThemeModePickerSheet.getThemeModeLabel(context, mode));
              },
            ),
            onTap: () => ThemeModePickerSheet.show(context),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          ListTile(
            title: WholeWordsText(
              l10n.language,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            trailing:
                _SettingValue(LanguageManager.currentLanguage.displayName),
            onTap: () {
              LanguagePickerSheet.show(
                context,
                onLanguageChanged: onLanguageChanged,
              );
            },
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          ListTile(
            title: WholeWordsText(
              l10n.currency,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            trailing: ValueListenableBuilder<Currency>(
              valueListenable: CurrencyFormatter.currencyNotifier,
              builder: (context, currency, child) {
                return _SettingValue(currency.localizedName);
              },
            ),
            onTap: () => CurrencyPickerSheet.show(context),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          const _AppLockTile(),
        ],
      ),
    );
  }
}

/// SEC-08: вход по блокировке телефона. Включение и выключение
/// подтверждаются отпечатком или PIN — так владелец сразу видит, что
/// проверка работает, а посторонний не снимет её с открытого телефона.
class _AppLockTile extends StatefulWidget {
  const _AppLockTile();

  @override
  State<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<_AppLockTile> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    final lock = AppLockService.instance;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      if (value && !await lock.isAvailable()) {
        if (mounted) AppAlerts.warning(context, l10n.app_lock_no_device_lock);
        return;
      }
      final result = await lock.authenticate(
        title: l10n.app_lock_prompt_title,
        reason: l10n.app_lock_reason,
      );
      if (!mounted) return;
      switch (result) {
        case AppLockResult.success:
          await lock.setEnabled(value);
        case AppLockResult.unavailable:
          // Блокировку экрана с телефона убрали — выключить можно и так.
          if (value) {
            AppAlerts.warning(context, l10n.app_lock_no_device_lock);
          } else {
            await lock.setEnabled(false);
          }
        case AppLockResult.lockedOut:
          AppAlerts.warning(context, l10n.app_lock_too_many_attempts);
        case AppLockResult.failed:
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: AppLockService.instance.enabled,
      builder: (context, enabled, _) => ListTile(
        key: const ValueKey('app_lock_tile'),
        title: WholeWordsText(
          context.l10n.app_lock_title,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: WholeWordsText(
          context.l10n.app_lock_subtitle,
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Switch(
          value: enabled,
          onChanged: _busy ? null : _toggle,
        ),
        onTap: _busy ? null : () => _toggle(!enabled),
      ),
    );
  }
}

/// Текущее значение настройки со стрелкой. Значению — до 40% ширины экрана
/// при обычном шрифте и меньше при крупном: длинное значение («Узбекский
/// сум») слегка уменьшается, а название настройки слева переносится между
/// словами, а не посреди слова («Валют / а», «оформлени / я»).
class _SettingValue extends StatelessWidget {
  final String value;

  const _SettingValue(this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width *
                0.4 /
                MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          ),
          child: OneLineLabel(
            value,
            alignment: AlignmentDirectional.centerEnd,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.of(context).accentText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.outline),
      ],
    );
  }
}
