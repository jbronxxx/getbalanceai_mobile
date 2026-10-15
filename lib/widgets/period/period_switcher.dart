import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import 'period_picker_sheet.dart';

/// Компактный переключатель месяца `‹ Октябрь ›`, общий для всех вкладок.
///
/// Стрелки листают месяцы (через границу года), тап по названию открывает
/// [PeriodPickerSheet]. Год показывается, только если он не текущий.
/// Состояние хранится в [SelectedPeriodService].
class PeriodSwitcher extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const PeriodSwitcher({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  /// Подпись периода: «Октябрь» для текущего года, «Октябрь 2025» — для других.
  static String label(MonthPeriod period, [DateTime? now]) {
    final name = LanguageManager.getMonthName(period.month);
    final currentYear = (now ?? DateTime.now()).year;
    return period.year == currentYear ? name : '$name ${period.year}';
  }

  @override
  Widget build(BuildContext context) {
    final service = SelectedPeriodService.instance;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: ValueListenableBuilder<MonthPeriod>(
        valueListenable: service.periodNotifier,
        builder: (context, period, _) {
          return Container(
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('period_previous'),
                  tooltip: context.l10n.previous_month,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: service.canGoBack ? service.previous : null,
                ),
                Expanded(
                  child: InkWell(
                    key: const ValueKey('period_label'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => PeriodPickerSheet.show(context),
                    child: Semantics(
                      button: true,
                      hint: context.l10n.select_month,
                      child: Center(
                        child: Text(
                          label(period),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('period_next'),
                  tooltip: context.l10n.next_month,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: service.canGoForward ? service.next : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
