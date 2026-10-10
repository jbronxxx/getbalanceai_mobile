import 'package:flutter/material.dart';
import '../../utils/utils.dart';

/// Виджет выбора периода (месяц и год) для экрана бюджетов.
class BudgetPeriodSelector extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const BudgetPeriodSelector({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: 20.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: selectedMonth,
              borderRadius: BorderRadius.circular(24),
              alignment: Alignment.center,
              decoration: InputDecoration(
                labelText: l10n.month_label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              items: List.generate(12, (index) {
                final monthValue = index + 1;
                final isCurrentMonth = monthValue == DateTime.now().month &&
                    selectedYear == DateTime.now().year;

                return DropdownMenuItem(
                  value: monthValue,
                  alignment: Alignment.center,
                  child: Text(
                    LanguageManager.monthsNames[index],
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentMonth
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  onMonthChanged(val);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: selectedYear,
              borderRadius: BorderRadius.circular(24),
              alignment: Alignment.center,
              decoration: InputDecoration(
                labelText: l10n.year_label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              items: List.generate(11, (index) {
                final yearValue = DateTime.now().year - 5 + index;
                final isCurrentYear = yearValue == DateTime.now().year;
                return DropdownMenuItem(
                  value: yearValue,
                  alignment: Alignment.center,
                  child: Text(
                    '$yearValue',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isCurrentYear ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentYear
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  onYearChanged(val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
