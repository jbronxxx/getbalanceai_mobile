import 'dart:async';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:flutter/material.dart';

/// Модальная форма создания/редактирования транзакции.
///
/// Если [transactionToEdit] передан — форма предзаполняется его данными и
/// сохранение обновляет существующую запись (сохраняя `localId`),
/// иначе создаётся новая запись. День операции выбирается в форме
/// (по умолчанию — сегодня), время берётся текущее либо исходное при
/// редактировании.
class AddTransactionSheet extends StatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionSheet({super.key, this.transactionToEdit});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _type;
  late Category _category;
  late DateTime _date;
  List<Category> _frequentCategories = const [];
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
    _date = t?.date ?? DateTime.now();
    _frequentCategories = _loadFrequentCategories(_type);
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

  /// Частые категории из истории; без инициализированной базы — пусто
  /// (порядок по умолчанию).
  List<Category> _loadFrequentCategories(TransactionType type) {
    if (!LocalDbService.isInitialized) return const [];
    try {
      return LocalDbService.instance.getFrequentCategories(type);
    } catch (e, s) {
      AppLogger.w('[AddTransaction] Frequent categories failed', e, s);
      return const [];
    }
  }

  void _onTypeChanged(TransactionType type) {
    if (type == _type) return;
    final frequent = _loadFrequentCategories(type);
    setState(() {
      _type = type;
      _frequentCategories = frequent;
      if (type == TransactionType.expense &&
          !Category.expenseCategories.contains(_category)) {
        _category = Category.food;
      } else if (type == TransactionType.income &&
          !Category.incomeCategories.contains(_category)) {
        _category = Category.salary;
      }
    });
  }

  /// Переносит выбранный день, сохраняя время: исходное при редактировании,
  /// текущее для новой записи — так порядок операций внутри дня не ломается.
  void _onDayChanged(DateTime day) {
    final time = widget.transactionToEdit?.date ?? DateTime.now();
    setState(() {
      _date = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
        time.second,
      );
    });
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
        dateMilliseconds: _date.millisecondsSinceEpoch,
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
        dateMilliseconds: _date.millisecondsSinceEpoch,
        description: _descriptionController.text.trim(),
        dateCreatedMilliseconds: 0,
      );
      LocalDbService.instance.saveTransaction(newTransaction);
    }

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

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transactionToEdit != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: AppSheet.decoration(context),
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
                const Center(
                  child: SheetHandle(),
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
                TransactionTypeToggle(type: _type, onChanged: _onTypeChanged),
                const SizedBox(height: 20),
                TransactionAmountField(
                  controller: _amountController,
                  currency: _selectedCurrency,
                  errorText: _amountError,
                  onCurrencyTap: _showCurrencyPicker,
                  autofocus: !isEditing,
                ),
                const SizedBox(height: 12),
                TransactionDateSelector(
                  date: _date,
                  onChanged: _onDayChanged,
                ),
                const SizedBox(height: 20),
                CategoryChipsSelector(
                  categories: _type == TransactionType.income
                      ? Category.incomeCategories
                      : Category.expenseCategories,
                  frequent: _frequentCategories,
                  selected: _category,
                  onSelected: (category) =>
                      setState(() => _category = category),
                ),
                const SizedBox(height: 20),
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
