import 'package:flutter/material.dart';
import 'package:getbalanceai_mobile/theme/app_colors.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

/// Плитки «Доход» и «Расход» на бирюзовых карточках «Баланса» и «Аналитики»:
/// одинаковые стрелки, цвета и шрифт на обоих экранах.
class IncomeExpenseTiles extends StatelessWidget {
  final double income;
  final double expense;

  const IncomeExpenseTiles({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tile(
            label: context.l10n.income_title,
            amount: income,
            icon: Icons.south_west_rounded,
            color: AppColors.incomeOnBrand,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            label: context.l10n.expense_title,
            amount: expense,
            icon: Icons.north_east_rounded,
            color: AppColors.expenseOnBrand,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _Tile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  /// Высота строки суммы без уменьшения — с учётом системного масштаба
  /// шрифта.
  static double _lineHeight(BuildContext context, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      color: AppColors.onBrandBase,
      fontWeight: FontWeight.bold,
    );

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
                  color: color.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
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
          // Длинная сумма уменьшается по ширине, но строка остаётся полной
          // высоты: иначе при крупном шрифте плитка с большой суммой
          // становилась ниже соседней.
          SizedBox(
            height: _lineHeight(context, amountStyle),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CurrencyFormatter.formatText(
                amount,
                style: amountStyle,
                useFittedBox: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
