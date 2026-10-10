import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../app_alerts.dart';

/// Модальный лист создания или редактирования лимита бюджета.
class AddBudgetSheet extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final Budget? budgetToEdit;
  final VoidCallback onSaved;

  const AddBudgetSheet({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    this.budgetToEdit,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required int selectedMonth,
    required int selectedYear,
    Budget? budgetToEdit,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBudgetSheet(
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
        budgetToEdit: budgetToEdit,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  late Category _selectedCategory;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.budgetToEdit?.category ?? Category.food;
    _amountController = TextEditingController(
      text: widget.budgetToEdit != null
          ? CurrencyFormatter.format(widget.budgetToEdit!.limitAmount,
              showSymbol: false)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    final amount = CurrencyFormatter.parseInput(_amountController.text);
    if (amount == null || amount <= 0) {
      AppAlerts.warning(context, context.l10n.alert_valid_amount);
      return;
    }

    if (amount > CurrencyFormatter.currentCurrency.maxAmount) {
      AppAlerts.warning(
        context,
        '${context.l10n.alert_amount_too_large} ${CurrencyFormatter.currentCurrency.code}',
      );
      return;
    }

    final spent = LocalDbService.instance.getSpentForCategory(
      widget.selectedMonth,
      widget.selectedYear,
      _selectedCategory.name,
    );

    final newBudget = Budget(
      localId: widget.budgetToEdit?.localId ?? 0,
      serverId: widget.budgetToEdit?.serverId,
      dbCategory: _selectedCategory.name,
      limitAmount: amount,
      month: widget.selectedMonth,
      year: widget.selectedYear,
      spent: spent,
      remaining: amount - spent,
      isModified: widget.budgetToEdit?.serverId != null,
    );

    LocalDbService.instance.saveBudget(newBudget);
    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isEditing = widget.budgetToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.only(
          top: 10,
          left: 24,
          right: 24,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
              isEditing
                  ? context.l10n.edit_budget_title
                  : context.l10n.add_budget_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<Category>(
              value: _selectedCategory,
              borderRadius: BorderRadius.circular(24),
              alignment: Alignment.centerLeft,
              decoration: InputDecoration(
                labelText: context.l10n.category_label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: Category.expenseCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.getLocalizedName(context)),
                );
              }).toList(),
              onChanged: isEditing
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [CurrencyInputFormatter()],
              autofocus: false,
              decoration: InputDecoration(
                labelText:
                    '${context.l10n.budget_amount_hint} (${CurrencyFormatter.currentCurrency.localizedSymbol})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saveBudget,
                child: Text(
                  context.l10n.save_btn,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
