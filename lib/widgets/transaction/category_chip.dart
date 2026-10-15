import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../dashboard/category_group_widget.dart';

/// Чип категории с иконкой и цветом категории.
class CategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      avatar: Icon(
        CategoryGroupWidget.getCategoryIcon(category),
        size: 18,
        color: CategoryGroupWidget.getCategoryColor(category),
      ),
      label: Text(category.getLocalizedName(context)),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        width: isSelected ? 1.5 : 1,
      ),
      shape: const StadiumBorder(),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
    );
  }
}
