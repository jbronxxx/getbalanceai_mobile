import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../keyboard_inset_padding.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

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
      backgroundColor: AppColors.transparent,
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
  String? _amountError;

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
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_amountError != null && mounted) {
      setState(() => _amountError = null);
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    final rawText = _amountController.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _amountError = context.l10n.amount_requirement_enter;
      });
      return;
    }

    final amount = CurrencyFormatter.parseInput(rawText);
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = context.l10n.amount_requirement_positive;
      });
      return;
    }

    final currentCurrency = CurrencyFormatter.currentCurrency;
    if (amount > currentCurrency.maxAmount) {
      setState(() {
        _amountError = context.l10n.amount_requirement_max(
          CurrencyFormatter.format(currentCurrency.maxAmount,
              showSymbol: false),
          currentCurrency.code,
        );
      });
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
    if (ApiService.instance.isAuthenticated == true) {
      unawaited(
        ApiService.instance.syncLocalDataToBackend().catchError((
          Object e,
          StackTrace s,
        ) {
          AppLogger.w('[Sync] Background push failed', e, s);
          return <String, dynamic>{};
        }),
      );
    }
    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isEditing = widget.budgetToEdit != null;
    final isDark = theme.brightness == Brightness.dark;

    return KeyboardInsetPadding(
      child: Container(
        padding: EdgeInsets.only(
          top: 10,
          left: 24,
          right: 24,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: AppSheet.decoration(context),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SheetHandle(),
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
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    CurrencyInputFormatter(
                        currency: CurrencyFormatter.currentCurrency),
                  ],
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: context.l10n.amount_label,
                    errorText: _amountError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.error,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.error,
                        width: 2,
                      ),
                    ),
                    errorStyle: TextStyle(
                      color: colorScheme.error,
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Category>(
                  value: _selectedCategory,
                  borderRadius: BorderRadius.circular(20),
                  dropdownColor: AppColors.of(context).dropdownBackground,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark
                        ? AppColors.highlightBase.withValues(alpha: 0.70)
                        : colorScheme.onSurfaceVariant,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: InputDecoration(
                    labelText: context.l10n.category_label,
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
        ),
      ),
    );
  }
}
