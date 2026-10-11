import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:flutter/material.dart';

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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.total_balance,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          CurrencyFormatter.formatText(
            balance,
            showSign: true,
            style: textTheme.headlineLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            useFittedBox: true,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _IncomeExpenseInfo(
                  label: context.l10n.income_title,
                  amount: income,
                  icon: Icons.arrow_downward,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IncomeExpenseInfo(
                  label: context.l10n.expense_title,
                  amount: expense,
                  icon: Icons.arrow_upward,
                  color: colorScheme.onPrimary,
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(icon, color: color.withValues(alpha: 0.95), size: 12),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color.withValues(alpha: 0.8),
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
              color: color,
              fontWeight: FontWeight.bold,
            ),
            useFittedBox: true,
          ),
        ],
      ),
    );
  }
}
