import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Чип выбора в общем стиле приложения (категории, дата операции, фильтры
/// поиска, период и формат отчёта): «таблетка», выбранный — с подсветкой и
/// контуром основного цвета.
class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;

  /// `null` — чип недоступен (например, пока идёт выгрузка).
  final VoidCallback? onTap;

  /// Иконка слева; окрашивается цветом подписи.
  final IconData? icon;

  /// Своя иконка слева (цвет категории) вместо [icon].
  final Widget? avatar;

  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        selected ? AppColors.of(context).accentText : colorScheme.onSurface;
    final icon = this.icon;

    return ChoiceChip(
      label: Text(label),
      avatar: avatar ??
          (icon == null ? null : Icon(icon, size: 16, color: foreground)),
      selected: selected,
      showCheckmark: false,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        width: selected ? 1.5 : 1,
      ),
      shape: const StadiumBorder(),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
