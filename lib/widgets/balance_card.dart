import 'package:flutter/material.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/theme/app_colors.dart';

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
          Row(
            children: [
              Expanded(
                child: _IncomeExpenseInfo(
                  label: context.l10n.income_title,
                  amount: income,
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.onBrandBase,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IncomeExpenseInfo(
                  label: context.l10n.expense_title,
                  amount: expense,
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.onBrandBase,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseInfo extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _IncomeExpenseInfo({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.onBrandBase.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.onBrandBase.withValues(alpha: 0.24),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.onBrandBase.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.onBrandBase,
                  size: 13,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onBrandBase.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CurrencyFormatter.formatText(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.onBrandBase,
              fontWeight: FontWeight.bold,
            ),
            useFittedBox: true,
          ),
        ],
      ),
    );
  }
}
