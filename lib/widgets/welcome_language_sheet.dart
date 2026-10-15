import 'package:flutter/material.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import 'app_sheet.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Модальный лист приветственной настройки при первом запуске приложения.
///
/// Позволяет пользователю выбрать язык интерфейса и основную валюту учета,
/// в которой будет рассчитываться общий баланс и бюджеты.
class WelcomeLanguageSheet extends StatelessWidget {
  const WelcomeLanguageSheet({super.key});

  /// Открывает экран приветственной настройки.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const WelcomeLanguageSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    Currency selectedCurrency = CurrencyFormatter.currentCurrency;
    bool currencyManuallyChanged = false;

    return Material(
      color: AppColors.transparent,
      child: Container(
        padding: EdgeInsets.only(
          top: 10,
          left: 24,
          right: 24,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: AppSheet.decoration(context),
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SheetHandle(width: 60, bottomMargin: 20),
                  ),
                  Text(
                    l10n.welcome_lang_title,
                    style: AppTypography.screenTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.welcome_lang_subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...AppLanguage.values.map((lang) {
                    final isSelected = LanguageManager.currentLanguage == lang;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : AppColors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : theme.dividerColor.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        title: Text(
                          lang.displayName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.of(context).accentText
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: AppColors.of(context).accentText,
                                size: 20)
                            : Icon(Icons.circle_outlined,
                                color: colorScheme.outline, size: 20),
                        onTap: () {
                          LanguageManager.setLanguage(lang);
                          if (!currencyManuallyChanged) {
                            if (lang == AppLanguage.uz) {
                              selectedCurrency = Currency.uzs;
                            } else if (lang == AppLanguage.kk) {
                              selectedCurrency = Currency.kzt;
                            } else if (lang == AppLanguage.ru) {
                              selectedCurrency = Currency.usd;
                            } else if (lang == AppLanguage.en) {
                              selectedCurrency = Currency.usd;
                            }
                          }
                          setModalState(() {});
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Text(
                    l10n.welcome_currency_title,
                    style: AppTypography.screenTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.welcome_currency_subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Currency.values.map((currency) {
                      final isCurSelected = selectedCurrency == currency;
                      return InkWell(
                        onTap: () {
                          currencyManuallyChanged = true;
                          selectedCurrency = currency;
                          setModalState(() {});
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCurSelected
                                ? colorScheme.primary.withValues(alpha: 0.12)
                                : colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurSelected
                                  ? colorScheme.primary
                                  : AppColors.transparent,
                              width: isCurSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currency.code,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCurSelected
                                      ? AppColors.of(context).accentText
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currency.localizedName,
                                style: textTheme.bodySmall?.copyWith(
                                  color: isCurSelected
                                      ? AppColors.of(context).accentText
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        PreferencesService.instance.saveLanguage(
                          LanguageManager.currentLanguage.code,
                        );
                        CurrencyFormatter.setCurrency(selectedCurrency);
                        Navigator.pop(context);
                      },
                      child: Text(
                        l10n.continue_btn,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
