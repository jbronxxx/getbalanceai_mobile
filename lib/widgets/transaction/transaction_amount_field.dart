import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Поле суммы операции с кнопкой выбора валюты и подсказкой пересчёта
/// в базовую валюту, если валюта чека отличается от базовой.
class TransactionAmountField extends StatelessWidget {
  final TextEditingController controller;
  final Currency currency;
  final String? errorText;
  final VoidCallback onCurrencyTap;
  final FocusNode? focusNode;

  const TransactionAmountField({
    super.key,
    required this.controller,
    required this.currency,
    required this.onCurrencyTap,
    this.errorText,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final isDifferentCurrency = currency != CurrencyFormatter.currentCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [CurrencyInputFormatter(currency: currency)],
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: context.l10n.amount_label,
            errorText: errorText,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: UnconstrainedBox(
                child: Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onCurrencyTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.highlightBase.withValues(alpha: 0.10)
                            : colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.highlightBase.withValues(alpha: 0.20)
                              : colorScheme.primary.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        currency.code,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.of(context).accentText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            errorStyle: TextStyle(
              color: colorScheme.error,
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Подсказка слушает поле сама: ввод суммы не перестраивает форму
        if (isDifferentCurrency)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final enteredAmount =
                  CurrencyFormatter.parseInput(value.text) ?? 0.0;
              if (enteredAmount <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_exchange,
                      size: 14,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _rateHint(context, enteredAmount),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// «≈ сумма (курс)» с пометкой о давности курса, если он устарел.
  String _rateHint(BuildContext context, double enteredAmount) {
    final exchange = CurrencyExchangeService.instance;
    final base = CurrencyFormatter.currentCurrency;
    final approxBase =
        exchange.convert(enteredAmount, from: currency, to: base);
    final rate = exchange.formatRateDescription(from: currency, to: base);

    var hint = '≈ ${CurrencyFormatter.format(approxBase)} ($rate)';
    if (exchange.isOutdated) {
      final lastUpdated = exchange.lastUpdated;
      final staleness = lastUpdated != null
          ? context.l10n
              .rate_updated_on(LanguageManager.formatDayMonth(lastUpdated))
          : context.l10n.rate_approximate;
      hint = '$hint • $staleness';
    }
    return hint;
  }
}
