import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';
import '../whole_words_text.dart';

/// Главная карточка вкладки «Бюджет» в стиле карточки баланса дашборда.
///
/// Текущий месяц — сколько можно тратить в день до конца месяца; прошлый —
/// итог по лимитам; будущий — запланированная сумма. Без лимитов — призыв
/// задать первый лимит и, если в прошлом месяце лимиты были, скопировать их.
class MonthBudgetCard extends StatelessWidget {
  final MonthBudgetSummary summary;
  final VoidCallback onAddLimit;

  /// Месяц, из которого можно скопировать лимиты в пустой месяц; `null` —
  /// кнопки копирования нет.
  final MonthPeriod? copyLimitsFrom;
  final VoidCallback? onCopyLimits;

  const MonthBudgetCard({
    super.key,
    required this.summary,
    required this.onAddLimit,
    this.copyLimitsFrom,
    this.onCopyLimits,
  }) : assert((copyLimitsFrom == null) == (onCopyLimits == null));

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
          : _EmptyContent(
              onAddLimit: onAddLimit,
              copyLimitsFrom: copyLimitsFrom,
              onCopyLimits: onCopyLimits,
            ),
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

    // В будущем месяце трат нет: пустая шкала ничего не добавляет к
    // «Запланировано».
    final showProgress = summary.periodState != BudgetPeriodState.future;

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
        // Относится к «Можно тратить в день»: при перерасходе её нет
        if (summary.periodState == BudgetPeriodState.current &&
            !summary.isExceeded &&
            summary.reservedCount > 0) ...[
          const SizedBox(height: 2),
          WholeWordsText(
            l10n.daily_allowance_reserved(
              summary.reservedCount,
              CurrencyFormatter.format(summary.reservedAmount),
            ),
            key: const ValueKey('month_budget_reserved'),
            style: textTheme.bodySmall?.copyWith(color: white82),
          ),
        ],
        if (showProgress) ...[
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
        ],
      ],
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final VoidCallback onAddLimit;
  final MonthPeriod? copyLimitsFrom;
  final VoidCallback? onCopyLimits;

  const _EmptyContent({
    required this.onAddLimit,
    this.copyLimitsFrom,
    this.onCopyLimits,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buttonTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final copyFrom = copyLimitsFrom;

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
        FilledButton(
          key: const ValueKey('month_budget_add_limit'),
          onPressed: onAddLimit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.onBrandBase,
            foregroundColor: AppColors.of(context).brandGradientStart,
            minimumSize: const Size(0, 46),
            shape: const StadiumBorder(),
            textStyle: buttonTextStyle,
          ),
          child: Text(context.l10n.add_limit_cta),
        ),
        if (copyFrom != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey('month_budget_copy_limits'),
            onPressed: onCopyLimits,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onBrandBase,
              side: BorderSide(
                color: AppColors.onBrandBase.withValues(alpha: 0.7),
                width: 1.2,
              ),
              minimumSize: const Size(0, 46),
              shape: const StadiumBorder(),
              textStyle: buttonTextStyle,
            ),
            child: Text(context.l10n.copy_limits_cta('m${copyFrom.month}')),
          ),
        ],
      ],
    );
  }
}
