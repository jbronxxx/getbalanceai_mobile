import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';

/// Главная карточка вкладки «Бюджет» в стиле карточки баланса дашборда.
///
/// Текущий месяц — сколько можно тратить в день до конца месяца; прошлый —
/// итог по лимитам; будущий — запланированная сумма. Без лимитов — призыв
/// задать первый лимит.
class MonthBudgetCard extends StatelessWidget {
  final MonthBudgetSummary summary;
  final VoidCallback onAddLimit;

  const MonthBudgetCard({
    super.key,
    required this.summary,
    required this.onAddLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.of(context).brandGradient,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.onBrandBase.withValues(alpha: 0.32),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).brandShadow,
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
      child: summary.hasLimits
          ? _SummaryContent(summary: summary)
          : _EmptyContent(onAddLimit: onAddLimit),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final MonthBudgetSummary summary;

  const _SummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final white82 = AppColors.onBrandBase.withValues(alpha: 0.82);

    final String headline;
    final double headlineAmount;
    String? caption;
    switch (summary.periodState) {
      case BudgetPeriodState.current:
        headline =
            summary.isExceeded ? l10n.budget_overspent : l10n.daily_allowance;
        headlineAmount =
            summary.isExceeded ? -summary.remaining : summary.dailyAllowance;
        caption = l10n.days_left(summary.daysLeft);
      case BudgetPeriodState.past:
        headline = summary.isExceeded
            ? l10n.budget_overspent
            : l10n.budget_month_result;
        headlineAmount = summary.remaining.abs();
      case BudgetPeriodState.future:
        headline = l10n.budget_planned;
        headlineAmount = summary.totalLimit;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: textTheme.titleSmall?.copyWith(
            color: white82,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        CurrencyFormatter.formatText(
          headlineAmount,
          useFittedBox: true,
          style: textTheme.headlineLarge?.copyWith(
            color: AppColors.onBrandBase,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption,
            style: textTheme.bodySmall?.copyWith(color: white82),
          ),
        ],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const ValueKey('month_budget_progress'),
            value: summary.spentRatio.clamp(0.0, 1.0),
            minHeight: 8,
            color: summary.isExceeded
                ? AppColors.of(context).exceededOnBrand
                : AppColors.of(context).onBrand,
            backgroundColor: AppColors.onBrandBase.withValues(alpha: 0.22),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: l10n.budget_limits_total,
                amount: summary.totalLimit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                label: l10n.budget_spent,
                amount: summary.totalSpent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                label: summary.isExceeded
                    ? l10n.budget_overspent
                    : l10n.budget_remaining,
                amount: summary.remaining.abs(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final double amount;

  const _Figure({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.onBrandBase.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.onBrandBase.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Подпись не обрезается, а уменьшается: три плашки в ряд узкие,
          // а «Перерасход» и переводы длиннее русских «Траты»/«Осталось».
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.onBrandBase.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          CurrencyFormatter.formatText(
            amount,
            useFittedBox: true,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.onBrandBase,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final VoidCallback onAddLimit;

  const _EmptyContent({required this.onAddLimit});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.month_budget_title,
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.onBrandBase,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.no_budgets_subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.onBrandBase.withValues(alpha: 0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('month_budget_add_limit'),
          onPressed: onAddLimit,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.l10n.add_limit_cta),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.onBrandBase,
            foregroundColor: AppColors.of(context).brandGradientStart,
            minimumSize: const Size(0, 46),
            shape: const StadiumBorder(),
            textStyle: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
