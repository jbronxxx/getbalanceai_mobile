import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../category_style.dart';
import '../app_choice_chip.dart';

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
    return AppChoiceChip(
      avatar: Icon(
        CategoryStyle.icon(category),
        size: 18,
        color: CategoryStyle.color(category),
      ),
      label: category.getLocalizedName(context),
      selected: isSelected,
      onTap: onTap,
    );
  }
}
