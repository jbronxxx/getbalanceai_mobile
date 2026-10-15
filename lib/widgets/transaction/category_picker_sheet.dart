import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'category_chip.dart';

/// Модальный лист со всеми категориями операции.
///
/// При длинном списке (больше [searchThreshold]) показывает поиск по
/// локализованному названию.
class CategoryPickerSheet extends StatefulWidget {
  final List<Category> categories;
  final Category selected;

  static const searchThreshold = 15;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selected,
  });

  /// Открывает лист и возвращает выбранную категорию (`null` — закрыт).
  static Future<Category?> show(
    BuildContext context, {
    required List<Category> categories,
    required Category selected,
  }) {
    return showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(
        categories: categories,
        selected: selected,
      ),
    );
  }

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSearch =
        widget.categories.length > CategoryPickerSheet.searchThreshold;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) =>
                c.getLocalizedName(context).toLowerCase().contains(query))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  context.l10n.all_categories,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (hasSearch) ...[
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.l10n.category_search_hint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        context.l10n.category_search_empty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in filtered)
                        CategoryChip(
                          key: ValueKey('category_sheet_${category.name}'),
                          category: category,
                          isSelected: category == widget.selected,
                          onTap: () => Navigator.pop(context, category),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
