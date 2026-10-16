import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../keyboard_inset_padding.dart';
import '../profile/currency_picker_sheet.dart';
import '../transaction/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Модальный лист создания или редактирования лимита бюджета.
///
/// Валюта лимита выбирается бейджем в поле суммы, как в форме операции
/// (по умолчанию — базовая). Категория выбирается чипами. Категории из
/// [limitedCategories] (лимит в этом месяце уже есть) не предлагаются; при
/// редактировании категория не меняется.
class AddBudgetSheet extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final Budget? budgetToEdit;
  final Set<Category> limitedCategories;
  final VoidCallback onSaved;

  const AddBudgetSheet({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    this.budgetToEdit,
    this.limitedCategories = const {},
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required int selectedMonth,
    required int selectedYear,
    Budget? budgetToEdit,
    Set<Category> limitedCategories = const {},
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
        limitedCategories: limitedCategories,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  late final List<Category> _categories;
  late final List<Category> _frequentCategories;
  late Category _selectedCategory;
  late Currency _selectedCurrency;
  late final TextEditingController _amountController;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final edited = widget.budgetToEdit?.category;
    final limited = widget.limitedCategories;
    _categories = edited != null
        ? [edited]
        : [...Category.expenseCategories.where((c) => !limited.contains(c))];
    _frequentCategories = _loadFrequentCategories();
    // Как и раньше — «Питание», если на него ещё нет лимита, иначе самая
    // частая из свободных категорий
    if (edited != null) {
      _selectedCategory = edited;
    } else if (_categories.contains(Category.food) || _categories.isEmpty) {
      _selectedCategory = Category.food;
    } else {
      _selectedCategory = CategoryChipsSelector.orderByFrequency(
        _categories,
        _frequentCategories,
      ).first;
    }
    final budget = widget.budgetToEdit;
    _selectedCurrency = budget?.currency ?? CurrencyFormatter.currentCurrency;
    _amountController = TextEditingController(
      text: budget != null
          ? CurrencyFormatter.format(
              budget.limitAmount,
              showSymbol: false,
              currency: _selectedCurrency,
            )
          : '',
    );
    _amountController.addListener(_onAmountChanged);
  }

  /// Частые категории расходов; без инициализированной базы — пусто.
  List<Category> _loadFrequentCategories() {
    if (!LocalDbService.isInitialized) return const [];
    try {
      return LocalDbService.instance
          .getFrequentCategories(TransactionType.expense);
    } catch (e, s) {
      AppLogger.w('[AddBudget] Frequent categories failed', e, s);
      return const [];
    }
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

  /// Меняет валюту лимита и пересчитывает введённую сумму по текущему
  /// курсу: лимит тот же, меняется только валюта, в которой он выражен.
  Future<void> _showCurrencyPicker() async {
    final previous = _selectedCurrency;
    final picked = await CurrencyPickerSheet.show(
      context,
      selectedCurrency: previous,
      updateGlobalCurrency: false,
    );
    if (picked == null || picked == previous || !mounted) return;
    setState(() {
      _selectedCurrency = picked;
      _amountError = null;
      final currentAmount =
          CurrencyFormatter.parseInput(_amountController.text);
      if (currentAmount != null && currentAmount > 0) {
        final converted = CurrencyExchangeService.instance
            .convert(currentAmount, from: previous, to: picked);
        _amountController.text = CurrencyFormatter.format(
          converted,
          showSymbol: false,
          currency: picked,
        );
      }
    });
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

    final currency = _selectedCurrency;
    if (amount > currency.maxAmount) {
      setState(() {
        _amountError = context.l10n.amount_requirement_max(
          CurrencyFormatter.format(
            currency.maxAmount,
            showSymbol: false,
            currency: currency,
          ),
          currency.code,
        );
      });
      return;
    }

    final spent = LocalDbService.instance.getSpentForCategory(
      widget.selectedMonth,
      widget.selectedYear,
      _selectedCategory.name,
      currency,
    );

    final newBudget = Budget(
      localId: widget.budgetToEdit?.localId ?? 0,
      serverId: widget.budgetToEdit?.serverId,
      dbCategory: _selectedCategory.name,
      limitAmount: amount,
      currencyCode: currency.code,
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
    final hasCategories = _categories.isNotEmpty;

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
                    CurrencyInputFormatter(currency: _selectedCurrency),
                  ],
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: context.l10n.amount_label,
                    errorText: _amountError,
                    suffixIcon: CurrencyBadge(
                      currency: _selectedCurrency,
                      onTap: _showCurrencyPicker,
                    ),
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
                const SizedBox(height: 4),
                if (hasCategories)
                  CategoryChipsSelector(
                    categories: _categories,
                    frequent: _frequentCategories,
                    selected: _selectedCategory,
                    onSelected: (category) =>
                        setState(() => _selectedCategory = category),
                  )
                else
                  Padding(
                    key: const ValueKey('budget_all_categories_limited'),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      context.l10n.budget_all_categories_limited,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                    onPressed: hasCategories ? _saveBudget : null,
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
