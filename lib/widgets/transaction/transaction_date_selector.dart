import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';

/// Выбор дня операции: «Сегодня», «Вчера» или произвольная дата из календаря.
///
/// Возвращает только день (время отбрасывается) — время операции
/// подставляет форма, чтобы сохранить порядок записей внутри дня.
class TransactionDateSelector extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  /// Текущий момент; параметр нужен для детерминированных тестов.
  final DateTime? now;

  const TransactionDateSelector({
    super.key,
    required this.date,
    required this.onChanged,
    this.now,
  });

  Future<void> _pickDate(BuildContext context, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date.isAfter(today) ? today : date,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) onChanged(DateUtils.dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = DateUtils.isSameDay(date, today);
    final isYesterday = DateUtils.isSameDay(date, yesterday);
    final isCustom = !isToday && !isYesterday;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DateChip(
          label: context.l10n.today,
          isSelected: isToday,
          onTap: () => onChanged(today),
        ),
        _DateChip(
          label: context.l10n.yesterday,
          isSelected: isYesterday,
          onTap: () => onChanged(yesterday),
        ),
        _DateChip(
          label: isCustom
              ? LanguageManager.formatDayMonth(date)
              : context.l10n.pick_date,
          icon: Icons.calendar_today_rounded,
          isSelected: isCustom,
          onTap: () => _pickDate(context, today),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isSelected
        ? AppColors.of(context).accentText
        : colorScheme.onSurfaceVariant;

    return ChoiceChip(
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: 16, color: foreground) : null,
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      shape: const StadiumBorder(),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
    );
  }
}
