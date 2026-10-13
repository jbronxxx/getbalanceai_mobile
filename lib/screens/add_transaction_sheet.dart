import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:flutter/material.dart';

/// Модальная форма создания/редактирования транзакции.
///
/// Если [transactionToEdit] передан — форма предзаполняется его данными и
/// сохранение обновляет существующую запись (сохраняя `localId`/дату),
/// иначе создаётся новая запись с текущей датой и временем.
class AddTransactionSheet extends StatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionSheet({super.key, this.transactionToEdit});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _type;
  late Category _category;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late Currency _selectedCurrency;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final t = widget.transactionToEdit;
    _type = t?.type ?? TransactionType.expense;
    _category = t?.category ??
        (_type == TransactionType.income ? Category.salary : Category.food);
    _selectedCurrency = t?.currency ?? CurrencyFormatter.currentCurrency;
    _amountController = TextEditingController(
      text: t != null
          ? CurrencyFormatter.format(t.amount, showSymbol: false)
          : '',
    );
    _amountController.addListener(_onAmountChanged);
    _descriptionController = TextEditingController(text: t?.description ?? '');
  }

  void _onAmountChanged() {
    if (_amountError != null) {
      _amountError = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showCurrencyPicker() async {
    final picked = await CurrencyPickerSheet.show(
      context,
      selectedCurrency: _selectedCurrency,
      updateGlobalCurrency: false,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedCurrency = picked;
        _amountError = null;
        final currentAmount =
            CurrencyFormatter.parseInput(_amountController.text);
        if (currentAmount != null && currentAmount > 0) {
          _amountController.text = CurrencyFormatter.format(
            currentAmount,
            showSymbol: false,
            currency: picked,
          );
        }
      });
    }
  }

  /// Валидирует сумму и сохраняет транзакцию. При невалидных данных
  /// отображает красный контур поля с компактным сообщением требования.
  void _save() {
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

    if (amount > _selectedCurrency.maxAmount) {
      setState(() {
        _amountError = context.l10n.amount_requirement_max(
          CurrencyFormatter.format(_selectedCurrency.maxAmount,
              showSymbol: false),
          _selectedCurrency.code,
        );
      });
      return;
    }

    final rate = CurrencyExchangeService.instance.getRate(
      from: _selectedCurrency,
      to: CurrencyFormatter.currentCurrency,
    );
    final baseAmount = CurrencyExchangeService.instance.convert(
      amount,
      from: _selectedCurrency,
      to: CurrencyFormatter.currentCurrency,
    );

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      // serverId и дату создания обязательно переносим в новый объект.
      // Если у транзакции уже есть serverId, выставляем isModified = true,
      // чтобы изменения были отправлены на бэкенд при следующей синхронизации.
      final updated = Transaction(
        localId: t.localId,
        serverId: t.serverId,
        dbType: _type.name,
        dbCategory: _category.name,
        amount: amount,
        currencyCode: _selectedCurrency.code,
        exchangeRate: rate,
        baseAmount: baseAmount,
        dateMilliseconds: t.date.millisecondsSinceEpoch,
        description: _descriptionController.text.trim(),
        dateCreatedMilliseconds: t.dateCreatedMilliseconds,
        isModified: t.serverId != null,
      );
      LocalDbService.instance.saveTransaction(updated);
    } else {
      final newTransaction = Transaction(
        dbType: _type.name,
        dbCategory: _category.name,
        amount: amount,
        currencyCode: _selectedCurrency.code,
        exchangeRate: rate,
        baseAmount: baseAmount,
        dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
        description: _descriptionController.text.trim(),
        dateCreatedMilliseconds: 0,
      );
      LocalDbService.instance.saveTransaction(newTransaction);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transactionToEdit != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF161618) : colorScheme.surface;
    final sheetBorder = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: sheetBorder, width: 1.5),
            left: BorderSide(color: sheetBorder, width: 1.0),
            right: BorderSide(color: sheetBorder, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.10),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: 10,
              left: 24,
              right: 24,
              bottom: 24,
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing
                      ? context.l10n.edit_transaction
                      : context.l10n.new_transaction,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _type = TransactionType.expense;
                            if (!Category.expenseCategories
                                .contains(_category)) {
                              _category = Category.food;
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _type == TransactionType.expense
                                  ? theme.cardColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _type == TransactionType.expense
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.shadow
                                            .withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              context.l10n.expense_title,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _type == TransactionType.expense
                                    ? colorScheme.onSurface
                                    : colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _type = TransactionType.income;
                            if (!Category.incomeCategories
                                .contains(_category)) {
                              _category = Category.salary;
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _type == TransactionType.income
                                  ? theme.cardColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _type == TransactionType.income
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.shadow
                                            .withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              context.l10n.income_title,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _type == TransactionType.income
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    final enteredAmount =
                        CurrencyFormatter.parseInput(_amountController.text) ??
                            0.0;
                    final isDifferentCurrency =
                        _selectedCurrency != CurrencyFormatter.currentCurrency;
                    final approxBase = CurrencyExchangeService.instance.convert(
                      enteredAmount,
                      from: _selectedCurrency,
                      to: CurrencyFormatter.currentCurrency,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            CurrencyInputFormatter(currency: _selectedCurrency),
                          ],
                          autofocus: false,
                          decoration: InputDecoration(
                            labelText: context.l10n.amount_label,
                            errorText: _amountError,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: UnconstrainedBox(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: _showCurrencyPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.10)
                                            : colorScheme.primary
                                                .withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.20)
                                              : colorScheme.primary
                                                  .withValues(alpha: 0.25),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        _selectedCurrency.code,
                                        style: textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFF2DD4BF)
                                              : colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isDifferentCurrency && enteredAmount > 0) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Icon(Icons.currency_exchange,
                                    size: 14, color: colorScheme.outline),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '≈ ${CurrencyFormatter.format(approxBase)} (${CurrencyExchangeService.instance.formatRateDescription(from: _selectedCurrency, to: CurrencyFormatter.currentCurrency)})'
                                    '${CurrencyExchangeService.instance.isOutdated ? (CurrencyExchangeService.instance.lastUpdated != null ? ' • обновлён ${LanguageManager.formatDayMonth(CurrencyExchangeService.instance.lastUpdated!)}' : ' • курс приблизительный') : ''}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Category>(
                  value: _category,
                  borderRadius: BorderRadius.circular(20),
                  dropdownColor:
                      isDark ? const Color(0xFF1E1E22) : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : colorScheme.onSurfaceVariant,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: InputDecoration(
                    labelText: context.l10n.category_label,
                  ),
                  items: (_type == TransactionType.income
                          ? Category.incomeCategories
                          : Category.expenseCategories)
                      .map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.getLocalizedName(context)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.l10n.description_label,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _save,
                    child: Text(
                      isEditing
                          ? context.l10n.save_changes_btn
                          : context.l10n.add_btn,
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
