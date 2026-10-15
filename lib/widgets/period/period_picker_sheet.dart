import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';

/// Лист выбора месяца: год со стрелками и сетка из 12 месяцев.
///
/// Выбор записывается в [SelectedPeriodService] и закрывает лист.
class PeriodPickerSheet extends StatefulWidget {
  const PeriodPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PeriodPickerSheet(),
    );
  }

  @override
  State<PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<PeriodPickerSheet> {
  final _service = SelectedPeriodService.instance;
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = _service.period.year;
  }

  void _select(int month) {
    _service.select(MonthPeriod(_year, month));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _service.period;
    final current = MonthPeriod.current();
    final earliest = _service.earliest;
    final latest = _service.latest;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      // Прокрутка спасает от переполнения на маленьких экранах и при
      // крупном системном шрифте.
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('period_sheet_previous_year'),
                    tooltip: context.l10n.previous_year,
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _year > earliest.year
                        ? () => setState(() => _year--)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('period_sheet_next_year'),
                    tooltip: context.l10n.next_year,
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _year < latest.year
                        ? () => setState(() => _year++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: [
                  for (var month = 1; month <= 12; month++)
                    _MonthCell(
                      key: ValueKey('period_sheet_month_$month'),
                      label: LanguageManager.getMonthName(month),
                      isSelected: selected == MonthPeriod(_year, month),
                      isCurrent: current == MonthPeriod(_year, month),
                      onTap: () => _select(month),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _MonthCell({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected ? colorScheme.primary : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected || isCurrent
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected || isCurrent
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : isCurrent
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
