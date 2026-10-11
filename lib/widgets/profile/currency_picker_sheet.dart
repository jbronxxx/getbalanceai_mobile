import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';

/// Модальный лист выбора валюты.
class CurrencyPickerSheet extends StatelessWidget {
  final Currency? selectedCurrency;
  final ValueChanged<Currency>? onCurrencySelected;
  final bool updateGlobalCurrency;

  const CurrencyPickerSheet({
    super.key,
    this.selectedCurrency,
    this.onCurrencySelected,
    this.updateGlobalCurrency = true,
  });

  /// Открывает лист выбора валюты.
  ///
  /// Если [updateGlobalCurrency] равен true (по умолчанию для настроек профиля),
  /// выбранная валюта сохраняется в [CurrencyFormatter] как базовая валюта приложения.
  /// Для локального выбора (например, валюты конкретной операции) передается `updateGlobalCurrency: false`.
  static Future<Currency?> show(
    BuildContext context, {
    Currency? selectedCurrency,
    ValueChanged<Currency>? onCurrencySelected,
    bool updateGlobalCurrency = true,
  }) {
    return showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CurrencyPickerSheet(
        selectedCurrency: selectedCurrency,
        onCurrencySelected: onCurrencySelected,
        updateGlobalCurrency: updateGlobalCurrency,
      ),
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
              context.l10n.select_currency,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...Currency.values.map((currency) {
              final activeCurrency =
                  selectedCurrency ?? CurrencyFormatter.currentCurrency;
              final isSelected = activeCurrency == currency;
              final label = currency.localizedName;

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
                onTap: () async {
                  if (updateGlobalCurrency) {
                    await CurrencyFormatter.setCurrency(currency);
                    if (ApiService.instance.isAuthenticated) {
                      unawaited(ApiService.instance
                          .updateUserProfile(baseCurrency: currency.code)
                          .catchError((_) {}));
                    }
                  }
                  if (onCurrencySelected != null) {
                    onCurrencySelected!(currency);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, currency);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
