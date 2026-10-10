import 'package:flutter/material.dart';
import '../../utils/utils.dart';

/// Модальный лист выбора периода (месяц и год) для экрана Dashboard.
class DashboardPeriodPickerSheet extends StatefulWidget {
  final int initialMonth;
  final int initialYear;
  final void Function(int month, int year) onPeriodSelected;

  const DashboardPeriodPickerSheet({
    super.key,
    required this.initialMonth,
    required this.initialYear,
    required this.onPeriodSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required int initialMonth,
    required int initialYear,
    required void Function(int month, int year) onPeriodSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DashboardPeriodPickerSheet(
        initialMonth: initialMonth,
        initialYear: initialYear,
        onPeriodSelected: onPeriodSelected,
      ),
    );
  }

  @override
  State<DashboardPeriodPickerSheet> createState() =>
      _DashboardPeriodPickerSheetState();
}

class _DashboardPeriodPickerSheetState
    extends State<DashboardPeriodPickerSheet> {
  late int _tempMonth;
  late int _tempYear;

  @override
  void initState() {
    super.initState();
    _tempMonth = widget.initialMonth;
    _tempYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.only(
          top: 10,
          left: 24,
          right: 24,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              context.l10n.select_period,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _tempMonth,
                    borderRadius: BorderRadius.circular(24),
                    alignment: Alignment.center,
                    decoration: InputDecoration(
                      labelText: context.l10n.month_label,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: List.generate(12, (index) {
                      final monthValue = index + 1;
                      final isCurrentMonth =
                          monthValue == DateTime.now().month &&
                              _tempYear == DateTime.now().year;

                      return DropdownMenuItem(
                        value: monthValue,
                        alignment: Alignment.center,
                        child: Text(
                          LanguageManager.monthsNames[index],
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: isCurrentMonth
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentMonth
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _tempMonth = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _tempYear,
                    borderRadius: BorderRadius.circular(24),
                    alignment: Alignment.center,
                    decoration: InputDecoration(
                      labelText: context.l10n.year_label,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: List.generate(11, (index) {
                      final yearValue = DateTime.now().year + index;
                      final isCurrentYear = yearValue == DateTime.now().year;
                      return DropdownMenuItem(
                        value: yearValue,
                        alignment: Alignment.center,
                        child: Text(
                          '$yearValue',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: isCurrentYear
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentYear
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _tempYear = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  widget.onPeriodSelected(_tempMonth, _tempYear);
                  Navigator.pop(context);
                },
                child: Text(
                  context.l10n.continue_btn,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
