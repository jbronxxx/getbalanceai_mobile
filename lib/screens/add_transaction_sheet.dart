import 'dart:async';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Модальная форма записи и регулярного платежа.
///
/// Режимы:
/// - новая запись (по умолчанию); чип «Каждый месяц» в строке дат делает
///   её регулярным платежом — с днём выбранной даты;
/// - [transactionToEdit] — правка записи (сохраняется `localId`);
/// - [occurrence] — «Оплачено» за месяц регулярного платежа: форма
///   заполнена платежом, сумму можно исправить;
/// - [recurringToEdit] — правка регулярного платежа;
/// - [draft] — новая запись, заполненная голосовым вводом; с [returnsDraft]
///   форма ничего не сохраняет, а возвращает исправленный черновик
///   ([editDraft]) — для списка распознанных записей.
///
/// День операции выбирается в форме (по умолчанию — сегодня), время
/// берётся текущее либо исходное при редактировании.
class AddTransactionSheet extends StatefulWidget {
  final Transaction? transactionToEdit;
  final RecurringOccurrence? occurrence;
  final RecurringPayment? recurringToEdit;
  final Transaction? draft;
  final bool returnsDraft;

  const AddTransactionSheet({
    super.key,
    this.transactionToEdit,
    this.occurrence,
    this.recurringToEdit,
    this.draft,
    this.returnsDraft = false,
  })  : assert((transactionToEdit == null ? 0 : 1) +
                (occurrence == null ? 0 : 1) +
                (recurringToEdit == null ? 0 : 1) +
                (draft == null ? 0 : 1) <=
            1),
        assert(!returnsDraft || draft != null);

  /// Открывает форму поверх экрана; `true` — что-то сохранено.
  static Future<bool?> show(
    BuildContext context, {
    Transaction? transactionToEdit,
    RecurringOccurrence? occurrence,
    RecurringPayment? recurringToEdit,
    Transaction? draft,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => AddTransactionSheet(
        transactionToEdit: transactionToEdit,
        occurrence: occurrence,
        recurringToEdit: recurringToEdit,
        draft: draft,
      ),
    );
  }

  /// Правка черновика без сохранения: исправленный черновик (с тем же
  /// `localId`) или `null`, если форму закрыли.
  static Future<Transaction?> editDraft(
    BuildContext context,
    Transaction draft,
  ) {
    return showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => AddTransactionSheet(draft: draft, returnsDraft: true),
    );
  }

  /// Дата записи «Оплачено» за месяц [period]: в текущем месяце — сейчас,
  /// за прошлый (оплата задним числом) — день платежа того месяца, чтобы
  /// запись попала в свой месяц.
  static DateTime paidDateFor(RecurringOccurrence occurrence, DateTime now) {
    if (!occurrence.period.isBefore(MonthPeriod.current(now))) return now;
    final due = occurrence.dueDate;
    return DateTime(due.year, due.month, due.day, now.hour, now.minute);
  }

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

  /// Повторять каждый месяц (регулярный платёж) и дата последнего платежа.
  late bool _repeat;
  DateTime? _repeatEnd;

  /// Платёж, по которому заполнена форма: оплачиваемый или изменяемый.
  RecurringPayment? get _template =>
      widget.recurringToEdit ?? widget.occurrence?.payment;

  bool get _isNewRecord =>
      widget.transactionToEdit == null &&
      widget.occurrence == null &&
      widget.recurringToEdit == null &&
      !widget.returnsDraft;

  /// Запись можно сделать регулярной: новая или правка обычной записи (не
  /// оплаты уже существующего регулярного платежа).
  late final bool _canRepeat = _isNewRecord ||
      (widget.transactionToEdit != null &&
          LocalDbService.isInitialized &&
          RecurringPaymentService.instance
                  .occurrenceForRecord(widget.transactionToEdit!) ==
              null);

  /// Форма задаёт расписание: новый регулярный платёж или его правка.
  bool get _editsSchedule => widget.recurringToEdit != null || _repeat;

  @override
  void initState() {
    super.initState();
    // Поля заполняются из изменяемой записи или распознанного черновика
    final t = widget.transactionToEdit ?? widget.draft;
    final template = _template;
    _type = t?.type ?? template?.type ?? TransactionType.expense;
    _category = t?.category ??
        template?.category ??
        (_type == TransactionType.income ? Category.salary : Category.food);
    final occurrence = widget.occurrence;
    _date = t?.date ??
        widget.recurringToEdit?.start ??
        (occurrence != null
            ? AddTransactionSheet.paidDateFor(occurrence, DateTime.now())
            : AddTransactionSheet.defaultDateFor(
                SelectedPeriodService.instance.period,
                DateTime.now(),
              ));
    _repeat = widget.recurringToEdit != null;
    _repeatEnd = widget.recurringToEdit?.end;
    _frequentCategories = _loadFrequentCategories(_type);
    _selectedCurrency =
        t?.currency ?? template?.currency ?? CurrencyFormatter.currentCurrency;
    final amount = t?.amount ?? template?.amount;
    _amountController = TextEditingController(
      text: amount != null
          ? CurrencyFormatter.formatForInput(amount, _selectedCurrency)
          : '',
    );
    _amountController.addListener(_onAmountChanged);
    _descriptionController = TextEditingController(
        text: t?.description ?? template?.description ?? '');
    if (t == null && template == null) {
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
  /// Срок регулярного платежа сдвигается вместе с днём: «12 платежей»
  /// остаются двенадцатью.
  void _onDayChanged(DateTime day) {
    final time = widget.transactionToEdit?.date ?? DateTime.now();
    final end = _repeatEnd;
    final count =
        end == null ? null : RecurringSchedule.paymentsCount(_date, end);
    setState(() {
      _date = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
        time.second,
      );
      if (count != null && count > 0) {
        _repeatEnd = RecurringSchedule.lastPaymentDate(_date, count);
      }
    });
  }

  /// Повтор выключается — дата снова не позже сегодня (запись не бывает
  /// в будущем).
  void _onRepeatChanged(bool repeat) {
    setState(() {
      _repeat = repeat;
      if (!repeat) {
        _repeatEnd = null;
        final now = DateTime.now();
        if (_date.isAfter(now)) _date = now;
      }
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

    final record = Transaction.newRecord(
      type: _type,
      category: _category,
      amount: amount,
      currency: _selectedCurrency,
      date: _date,
      description: _descriptionController.text.trim(),
    );

    if (widget.returnsDraft) {
      record.localId = widget.draft!.localId;
      Navigator.pop(context, record);
      return;
    }

    final recurring = RecurringPaymentService.instance;
    final occurrence = widget.occurrence;
    final recurringToEdit = widget.recurringToEdit;
    if (occurrence != null) {
      LocalDbService.instance
          .saveTransaction(recurring.asPaidRecord(occurrence, record));
    } else if (recurringToEdit != null) {
      final start = DateUtils.dateOnly(_date);
      recurring.save(recurringToEdit.copyWith(
        dbType: _type.name,
        // Неизвестная этой версии категория не превращается в «Прочее»
        dbCategory: _category == recurringToEdit.category &&
                _type == recurringToEdit.type
            ? recurringToEdit.dbCategory
            : _category.name,
        amount: amount,
        currencyCode: _selectedCurrency.code,
        description: record.description,
        dayOfMonth: start.day,
        startDate: formatDateOnly(start),
        endDate: () => _repeatEnd == null ? null : formatDateOnly(_repeatEnd!),
      ));
    } else {
      final t = widget.transactionToEdit;
      // Правка: localId, serverId и дата создания переносятся в новый объект;
      // запись с serverId помечается изменённой, чтобы правка ушла на сервер.
      final saved = t == null
          ? record
          : Transaction(
              localId: t.localId,
              serverId: t.serverId,
              dbType: _type.name,
              // Категория и тип не менялись — сохраняем исходную строку:
              // категория, неизвестная этой версии клиента, показана как
              // «Прочее», но не должна им перезаписаться.
              dbCategory: _category == t.category && _type == t.type
                  ? t.dbCategory
                  : _category.name,
              amount: amount,
              currencyCode: _selectedCurrency.code,
              exchangeRate: record.exchangeRate,
              baseAmount: record.baseAmount,
              dateMilliseconds: record.dateMilliseconds,
              description: record.description,
              dateCreatedMilliseconds: t.dateCreatedMilliseconds,
              isModified: t.serverId != null,
            );
      if (_repeat) {
        recurring.startFrom(saved,
            start: DateUtils.dateOnly(_date), end: _repeatEnd);
        // Разрешение на напоминания — когда они впервые понадобились
        unawaited(RecurringReminderService.instance.requestPermission());
      } else {
        LocalDbService.instance.saveTransaction(saved);
      }
    }

    ApiService.instance.pushLocalChangesInBackground();

    Navigator.pop(context, true);
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    final isIncome = _type == TransactionType.income;
    if (widget.occurrence != null) {
      return isIncome ? l10n.recurring_receive_title : l10n.recurring_pay_title;
    }
    if (widget.recurringToEdit != null) {
      return isIncome
          ? l10n.recurring_income_title
          : l10n.recurring_payment_title;
    }
    return widget.transactionToEdit != null || widget.returnsDraft
        ? l10n.edit_transaction
        : l10n.new_transaction;
  }

  String _submitLabel(BuildContext context) {
    final l10n = context.l10n;
    if (widget.occurrence != null) {
      return _type == TransactionType.income
          ? l10n.recurring_received_btn
          : l10n.recurring_paid_btn;
    }
    if (widget.recurringToEdit != null) return l10n.save_btn;
    if (widget.returnsDraft) return l10n.done_btn;
    if (_repeat) {
      return widget.transactionToEdit != null
          ? l10n.save_btn
          : l10n.recurring_add_btn;
    }
    return widget.transactionToEdit != null
        ? l10n.save_changes_btn
        : l10n.add_btn;
  }

  @override
  Widget build(BuildContext context) {
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
                        WholeWordsText(
                          _title(context),
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        // Тип оплачиваемого платежа задан расписанием
                        if (widget.occurrence == null) ...[
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
                        ],
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
                          // Будущий день — только у расписания: у правки
                          // существующей записи дата остаётся датой записи
                          allowFuture: widget.recurringToEdit != null ||
                              (_repeat && _isNewRecord),
                          extraChips:
                              _canRepeat || widget.recurringToEdit != null
                                  ? recurrenceChips(
                                      context,
                                      enabled: _editsSchedule,
                                      start: _date,
                                      end: _repeatEnd,
                                      onToggle:
                                          _canRepeat ? _onRepeatChanged : null,
                                      onEndChanged: (end) =>
                                          setState(() => _repeatEnd = end),
                                    )
                                  : const [],
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
                  label: _submitLabel(context),
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
