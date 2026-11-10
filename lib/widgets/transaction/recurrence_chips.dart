import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../app_choice_chip.dart';
import '../app_options_sheet.dart';

/// Чипы повтора для строки дат формы записи (см.
/// [TransactionDateSelector.extraChips]): «Каждый месяц», а когда повтор
/// включён — «Каждое 15-е» и срок («Без срока», «12 платежей»).
///
/// День платежа — день выбранной в форме даты [start]; срок — дата последнего
/// платежа [end] (`null` — без срока).
List<Widget> recurrenceChips(
  BuildContext context, {
  required bool enabled,
  required DateTime start,
  required DateTime? end,
  required ValueChanged<bool>? onToggle,
  required ValueChanged<DateTime?> onEndChanged,
}) {
  final l10n = context.l10n;
  if (!enabled) {
    return [
      AppChoiceChip(
        key: const ValueKey('recurrence_toggle'),
        label: l10n.recurring_every_month,
        icon: Icons.repeat_rounded,
        selected: false,
        onTap: () => onToggle?.call(true),
      ),
    ];
  }
  final last = end;
  return [
    AppChoiceChip(
      key: const ValueKey('recurrence_toggle'),
      label: l10n.recurring_every_day(start.day),
      icon: Icons.repeat_rounded,
      selected: true,
      // Правку регулярного платежа повтор не выключает: для этого «Остановить»
      onTap: () => onToggle?.call(false),
    ),
    AppChoiceChip(
      key: const ValueKey('recurrence_end'),
      label: last == null
          ? l10n.recurring_end_none
          : l10n.recurring_end_count(
              RecurringSchedule.paymentsCount(start, last)),
      icon: Icons.event_repeat_rounded,
      selected: false,
      onTap: () => _pickEnd(context, start, end, onEndChanged),
    ),
  ];
}

/// Варианты срока: без срока, 3/6/12/24 платежа или своя дата.
Future<void> _pickEnd(
  BuildContext context,
  DateTime start,
  DateTime? end,
  ValueChanged<DateTime?> onEndChanged,
) async {
  final l10n = context.l10n;
  final current =
      end == null ? null : RecurringSchedule.paymentsCount(start, end);
  const pickDate = -1;
  final choice = await AppOptionsSheet.show<int>(
    context,
    title: l10n.recurring_end_title,
    options: [
      AppSheetOption(
        value: 0,
        label: l10n.recurring_end_none,
        icon: Icons.all_inclusive_rounded,
        selected: end == null,
      ),
      for (final count in const [3, 6, 12, 24])
        AppSheetOption(
          value: count,
          label: l10n.recurring_end_count(count),
          icon: Icons.event_repeat_rounded,
          selected: current == count,
        ),
      AppSheetOption(
        value: pickDate,
        label: l10n.recurring_end_pick_date,
        icon: Icons.calendar_today_rounded,
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  if (choice == 0) return onEndChanged(null);
  if (choice > 0) {
    return onEndChanged(RecurringSchedule.lastPaymentDate(start, choice));
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: end ?? RecurringSchedule.lastPaymentDate(start, 12),
    firstDate: DateUtils.dateOnly(start),
    lastDate: DateTime(start.year + 30, 12, 31),
  );
  if (picked != null) onEndChanged(DateUtils.dateOnly(picked));
}
