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

  @override
  void initState() {
    super.initState();
    final t = widget.transactionToEdit;
    _type = t?.type ?? TransactionType.expense;
    _category = t?.category ??
        (_type == TransactionType.income ? Category.salary : Category.food);
    _amountController = TextEditingController(
      text: t != null
          ? CurrencyFormatter.format(t.amount, showSymbol: false)
          : '',
    );
    _descriptionController = TextEditingController(text: t?.description ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Валидирует сумму (принимает и запятую, и точку как десятичный
  /// разделитель) и сохраняет транзакцию — новую или обновлённую.
  void _save() {
    final amount = CurrencyFormatter.parseInput(_amountController.text);

    if (amount == null || amount <= 0) {
      AppAlerts.warning(context, context.l10n.alert_valid_amount);
      return;
    }

    if (amount > CurrencyFormatter.currentCurrency.maxAmount) {
      AppAlerts.warning(context,
          '${context.l10n.alert_amount_too_large} ${CurrencyFormatter.currentCurrency.code}');
      return;
    }

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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                      color: colorScheme.outlineVariant,
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
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText:
                        '${context.l10n.amount_label} (${CurrencyFormatter.currentCurrency.localizedSymbol})',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                Theme(
                  data: theme.copyWith(
                    shadowColor: colorScheme.shadow,
                  ),
                  child: DropdownButtonFormField<Category>(
                    value: _category,
                    borderRadius: BorderRadius.circular(24),
                    dropdownColor: theme.cardColor,
                    elevation: 16,
                    alignment: Alignment.centerLeft,
                    decoration: InputDecoration(
                      labelText: context.l10n.category_label,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
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
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
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
