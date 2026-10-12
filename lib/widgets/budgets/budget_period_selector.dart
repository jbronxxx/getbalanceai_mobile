import 'package:flutter/material.dart';
import '../../utils/utils.dart';

/// Виджет выбора периода (месяц и год) для экрана бюджетов.
class BudgetPeriodSelector extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final EdgeInsetsGeometry? padding;

  const BudgetPeriodSelector({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;

    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFCBD5E1);
    final fieldFillColor = isDark ? const Color(0xFF18181C) : Colors.white;
    final dropdownBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: padding ??
          const EdgeInsets.only(
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
              borderRadius: BorderRadius.circular(20),
              dropdownColor: dropdownBg,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: iconColor,
              ),
              alignment: Alignment.center,
              decoration: InputDecoration(
                labelText: l10n.month_label,
                filled: true,
                fillColor: fieldFillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.5),
                ),
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
              borderRadius: BorderRadius.circular(20),
              dropdownColor: dropdownBg,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: iconColor,
              ),
              alignment: Alignment.center,
              decoration: InputDecoration(
                labelText: l10n.year_label,
                filled: true,
                fillColor: fieldFillColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.5),
                ),
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
