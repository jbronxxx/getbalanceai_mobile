import 'package:flutter/material.dart';
import '../models/models.dart';
import 'category_style.dart';
import 'whole_words_text.dart';

/// Иконка категории в цветной плашке — в строках операций и регулярных
/// платежей.
class CategoryIconBadge extends StatelessWidget {
  final Category category;

  /// Сторона плашки.
  static const size = 40.0;

  const CategoryIconBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Icon(CategoryStyle.icon(category), color: color, size: 20),
    );
  }
}

/// Иконка и название категории в строку — значение в карточке операции
/// или регулярного платежа; название переносится между словами.
class CategoryInlineLabel extends StatelessWidget {
  final Category category;

  const CategoryInlineLabel({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CategoryStyle.icon(category),
          size: 18,
          color: CategoryStyle.color(category),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: WholeWordsText(
            category.getLocalizedName(context),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
