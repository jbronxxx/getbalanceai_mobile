import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'category_chip.dart';
import 'category_picker_sheet.dart';

/// Выбор категории операции в один тап.
///
/// Показывает не больше [maxVisible] категорий — сначала часто используемые
/// ([frequent]), затем остальные в порядке [categories] — и чип «Ещё»,
/// открывающий полный список. Высота блока не растёт вместе со списком
/// категорий. Если категорий не больше `maxVisible + 1`, видны все.
class CategoryChipsSelector extends StatelessWidget {
  final List<Category> categories;
  final List<Category> frequent;
  final Category selected;
  final ValueChanged<Category> onSelected;
  final int maxVisible;

  const CategoryChipsSelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.frequent = const [],
    this.maxVisible = 5,
  });

  /// Все категории: сначала частые (только из [categories]), затем остальные.
  static List<Category> orderByFrequency(
    List<Category> categories,
    List<Category> frequent,
  ) {
    final ordered = [
      for (final c in frequent)
        if (categories.contains(c)) c,
    ];
    for (final c in categories) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ordered;
  }

  /// Видимые чипы: первые [maxVisible] из [ordered]; выбранная категория
  /// всегда видна — если её нет среди первых, она встаёт первой.
  static List<Category> visibleCategories(
    List<Category> ordered,
    Category selected,
    int maxVisible,
  ) {
    if (ordered.length <= maxVisible + 1) return ordered;
    final visible = ordered.take(maxVisible).toList();
    if (visible.contains(selected)) return visible;
    return [selected, ...visible.take(maxVisible - 1)];
  }

  Future<void> _openAll(BuildContext context, List<Category> ordered) async {
    final picked = await CategoryPickerSheet.show(
      context,
      categories: ordered,
      selected: selected,
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ordered = orderByFrequency(categories, frequent);
    final visible = visibleCategories(ordered, selected, maxVisible);
    final hasMore = visible.length < ordered.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l10n.category_label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in visible)
              CategoryChip(
                key: ValueKey('category_chip_${category.name}'),
                category: category,
                isSelected: category == selected,
                onTap: () => onSelected(category),
              ),
            if (hasMore)
              ActionChip(
                key: const ValueKey('category_chip_more'),
                avatar: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                label: Text(context.l10n.more_categories),
                onPressed: () => _openAll(context, ordered),
                side: BorderSide(color: colorScheme.outlineVariant),
                shape: const StadiumBorder(),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
