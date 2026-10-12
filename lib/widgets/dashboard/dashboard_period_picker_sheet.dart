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
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF161618) : colorScheme.surface;
    final sheetBorder = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);

    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFCBD5E1);
    final fieldFillColor = isDark ? const Color(0xFF202024) : Colors.white;
    final dropdownBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : colorScheme.onSurfaceVariant;

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
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: sheetBorder, width: 1.5),
            left: BorderSide(color: sheetBorder, width: 1.0),
            right: BorderSide(color: sheetBorder, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.10),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : colorScheme.outlineVariant,
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
                    borderRadius: BorderRadius.circular(20),
                    dropdownColor: dropdownBg,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: iconColor,
                    ),
                    alignment: Alignment.center,
                    decoration: InputDecoration(
                      labelText: context.l10n.month_label,
                      filled: true,
                      fillColor: fieldFillColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                        borderSide:
                            BorderSide(color: Color(0xFF0F766E), width: 1.5),
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
                    borderRadius: BorderRadius.circular(20),
                    dropdownColor: dropdownBg,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: iconColor,
                    ),
                    alignment: Alignment.center,
                    decoration: InputDecoration(
                      labelText: context.l10n.year_label,
                      filled: true,
                      fillColor: fieldFillColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                        borderSide:
                            BorderSide(color: Color(0xFF0F766E), width: 1.5),
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
