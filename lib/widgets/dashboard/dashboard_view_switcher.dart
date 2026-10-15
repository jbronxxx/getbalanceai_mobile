import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';

/// Вид ленты дашборда.
enum DashboardViewMode {
  /// Операции по дням (журнал).
  days,

  /// Итоги категорий за месяц с раскрывающимися списками.
  categories,
}

/// Переключатель «По дням / По категориям»: две раздельные овальные кнопки
/// той же высоты и формы, что и переключатель месяца.
class DashboardViewSwitcher extends StatelessWidget {
  final DashboardViewMode mode;
  final ValueChanged<DashboardViewMode> onChanged;

  const DashboardViewSwitcher({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ViewPill(
            key: const ValueKey('view_mode_days'),
            label: context.l10n.view_by_days,
            isSelected: mode == DashboardViewMode.days,
            onTap: () => onChanged(DashboardViewMode.days),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ViewPill(
            key: const ValueKey('view_mode_categories'),
            label: context.l10n.view_by_categories,
            isSelected: mode == DashboardViewMode.categories,
            onTap: () => onChanged(DashboardViewMode.categories),
          ),
        ),
      ],
    );
  }
}

class _ViewPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = isSelected
        ? AppColors.of(context).accentText
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: ShapeDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : AppColors.transparent,
              width: 1.2,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: isSelected ? null : onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AnimatedDefaultTextStyle(
                  duration: _duration,
                  curve: Curves.easeOutCubic,
                  style: (theme.textTheme.labelLarge ?? const TextStyle())
                      .copyWith(
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
