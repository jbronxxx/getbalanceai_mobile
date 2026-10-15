import 'package:flutter/material.dart';
import '../../utils/utils.dart';

/// Заголовок блока лимитов на экране «Финансы» с кнопкой добавления лимита.
class BudgetsSectionHeader extends StatelessWidget {
  final VoidCallback onAdd;

  const BudgetsSectionHeader({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.budgets_title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('budgets_add_button'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(context.l10n.add_limit_btn),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }
}
