import 'package:flutter/material.dart';
import 'package:getbalanceai_mobile/services/preferences_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/theme/app_colors.dart';
import 'package:getbalanceai_mobile/widgets/income_expense_tiles.dart';

/// Главная карточка баланса на дашборде, выполненная в стиле полированного
/// бирюзового жидкого стекла (Polished Turquoise Liquid Glass).
///
/// «Глазок» в углу скрывает баланс, доход и расход (SEC-08); выбор
/// запоминается.
class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = AppColors.of(context);
    final balanceStyle = textTheme.headlineLarge?.copyWith(
      color: AppColors.onBrandBase,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: PreferencesService.instance.hideBalanceNotifier,
      builder: (context, hidden, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: colors.brandGradient,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.onBrandBase.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.brandShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.shadowBase.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.month_total,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.onBrandBase.withValues(alpha: 0.82),
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _HideAmountsButton(hidden: hidden),
              ],
            ),
            // Отступ до баланса даёт кнопка «глазка» (36) выше строки заголовка
            if (hidden)
              Text(CurrencyFormatter.hiddenAmount, style: balanceStyle)
            else
              CurrencyFormatter.formatText(
                balance,
                showSign: true,
                style: balanceStyle,
                useFittedBox: true,
              ),
            const SizedBox(height: 22),
            IncomeExpenseTiles(
                income: income, expense: expense, hidden: hidden),
          ],
        ),
      ),
    );
  }
}

class _HideAmountsButton extends StatelessWidget {
  final bool hidden;

  const _HideAmountsButton({required this.hidden});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('balance_hide_amounts'),
      tooltip: hidden ? context.l10n.balance_show : context.l10n.balance_hide,
      onPressed: () => PreferencesService.instance.setHideBalance(!hidden),
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
      ),
      color: AppColors.onBrandBase.withValues(alpha: 0.82),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
