import 'package:flutter/material.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/theme/app_colors.dart';
import 'package:getbalanceai_mobile/widgets/income_expense_tiles.dart';

/// Главная карточка баланса на дашборде, выполненная в стиле полированного
/// бирюзового жидкого стекла (Polished Turquoise Liquid Glass).
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

    return Container(
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
          Text(
            context.l10n.month_total,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.onBrandBase.withValues(alpha: 0.82),
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          CurrencyFormatter.formatText(
            balance,
            showSign: true,
            style: textTheme.headlineLarge?.copyWith(
              color: AppColors.onBrandBase,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            useFittedBox: true,
          ),
          const SizedBox(height: 22),
          IncomeExpenseTiles(income: income, expense: expense),
        ],
      ),
    );
  }
}
