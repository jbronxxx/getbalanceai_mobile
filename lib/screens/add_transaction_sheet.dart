import 'dart:async';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Дата новой операции: в открытом прошлом месяце — его последний день
  /// (иначе запись молча уходила в «сегодня» и не появлялась на экране),
  /// в текущем и будущих — сейчас: будущие даты календарь не разрешает.
  static DateTime defaultDateFor(MonthPeriod period, DateTime now) {
    if (!period.isBefore(MonthPeriod.current(now))) return now;
    final lastDay = DateTime(period.year, period.month + 1, 0).day;
    return DateTime(
      period.year,
      period.month,
      lastDay,
      now.hour,
      now.minute,
      now.second,
    );
  }

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
  final FocusNode _amountFocusNode = FocusNode();
  Animation<double>? _routeAnimation;
  late Currency _selectedCurrency;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final t = widget.transactionToEdit;
    _type = t?.type ?? TransactionType.expense;
    _category = t?.category ??
        (_type == TransactionType.income ? Category.salary : Category.food);
    _date = t?.date ??
        AddTransactionSheet.defaultDateFor(
          SelectedPeriodService.instance.period,
          DateTime.now(),
        );
    _frequentCategories = _loadFrequentCategories(_type);
    _selectedCurrency = t?.currency ?? CurrencyFormatter.currentCurrency;
    _amountController = TextEditingController(
      text: t != null
          ? CurrencyFormatter.formatForInput(t.amount, _selectedCurrency)
          : '',
    );
    _amountController.addListener(_onAmountChanged);
    _descriptionController = TextEditingController(text: t?.description ?? '');
    if (t == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focusAmountAfterOpen());
    }
  }

  /// Клавиатура для новой операции открывается после выезда листа:
  /// одновременная анимация листа и клавиатуры даёт заметный фриз.
  void _focusAmountAfterOpen() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _amountFocusNode.requestFocus();
      return;
    }
    _routeAnimation = animation..addStatusListener(_onRouteAnimationStatus);
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = null;
    if (mounted) _amountFocusNode.requestFocus();
  }

  /// Ошибка суммы сбрасывается при вводе. Лист перестраивается только ради
  /// этого: подсказку курса поле суммы обновляет само.
  void _onAmountChanged() {
    if (_amountError == null || !mounted) return;
    setState(() => _amountError = null);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _amountFocusNode.dispose();
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
          _amountController.text =
              CurrencyFormatter.formatForInput(currentAmount, picked);
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
          CurrencyFormatter.format(
            _selectedCurrency.maxAmount,
            showSymbol: false,
            currency: _selectedCurrency,
          ),
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
        // Категория и тип не менялись — сохраняем исходную строку: категория,
        // неизвестная этой версии клиента, показана как «Прочее», но не
        // должна им перезаписаться.
        dbCategory: _category == t.category && _type == t.type
            ? t.dbCategory
            : _category.name,
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

    ApiService.instance.pushLocalChangesInBackground();

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transactionToEdit != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Лист поднимается на высоту клавиатуры; форма прокручивается, а кнопка
    // сохранения закреплена внизу и всегда видна над клавиатурой.
    return KeyboardInsetPadding(
      child: Container(
        decoration: AppSheet.decoration(context),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(
                    top: 10,
                    left: 24,
                    right: 24,
                    bottom: 8,
                  ),
                  // Отдельный слой: пока клавиатура сужает область прокрутки,
                  // форма не перерисовывается, а только сдвигается.
                  child: RepaintBoundary(
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
                        // Тип часто выбирают до или во время ввода суммы:
                        // для «тапа вне поля» переключатель — часть поля,
                        // клавиатура при смене типа не закрывается.
                        TextFieldTapRegion(
                          child: TransactionTypeToggle(
                            type: _type,
                            onChanged: _onTypeChanged,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TransactionAmountField(
                          controller: _amountController,
                          currency: _selectedCurrency,
                          errorText: _amountError,
                          onCurrencyTap: _showCurrencyPicker,
                          focusNode: _amountFocusNode,
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
                          onTapOutside: unfocusOnTapOutside,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                Transaction.descriptionMaxLength),
                          ],
                          decoration: InputDecoration(
                            labelText: context.l10n.description_label,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SheetPrimaryButton(
                  key: const ValueKey('add_transaction_submit'),
                  label: isEditing
                      ? context.l10n.save_changes_btn
                      : context.l10n.add_btn,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
