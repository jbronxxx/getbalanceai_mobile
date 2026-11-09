import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../budgets/budget_expense_ratio_card.dart';
import '../reload_when_visible.dart';

/// Структура расходов выбранного месяца (кольцо по категориям) над AI-советами.
///
/// Данные локальные: секция сама перечитывает их при смене месяца, валюты
/// и после сохранения операций. Пустой месяц не показывается — об этом
/// сообщает карточка AI ниже.
class ExpenseStructureSection extends StatefulWidget {
  const ExpenseStructureSection({super.key});

  @override
  State<ExpenseStructureSection> createState() =>
      _ExpenseStructureSectionState();
}

class _ExpenseStructureSectionState extends State<ExpenseStructureSection>
    with ReloadWhenVisible {
  double _income = 0;
  double _expense = 0;
  Map<Category, double> _byCategory = {};

  @override
  void initState() {
    super.initState();
    _load();
    SelectedPeriodService.instance.periodNotifier.addListener(_reload);
    CurrencyFormatter.currencyNotifier.addListener(_reload);
    LocalDbService.transactionsChanged.addListener(_reload);
    UndoableDeletions.transactions.addListener(_reload);
  }

  @override
  void dispose() {
    SelectedPeriodService.instance.periodNotifier.removeListener(_reload);
    CurrencyFormatter.currencyNotifier.removeListener(_reload);
    LocalDbService.transactionsChanged.removeListener(_reload);
    UndoableDeletions.transactions.removeListener(_reload);
    super.dispose();
  }

  /// У скрытой вкладки «Аналитика» — при её показе.
  void _reload() => requestReload();

  @override
  void reloadData() => setState(_load);

  void _load() {
    if (!LocalDbService.isInitialized) return;
    final period = SelectedPeriodService.instance.period;
    final db = LocalDbService.instance;
    // Операции, скрытые в ожидании удаления, уже не учитываются
    final deletions = UndoableDeletions.transactions;
    final transactions = db
        .getTransactionsForPeriod(period.month, period.year)
        .where((t) => !deletions.isPending(t))
        .toList(growable: false);
    final totals = db.totalsFor(transactions);
    _income = totals['income'] ?? 0;
    _expense = totals['expense'] ?? 0;
    // Неизвестные клиенту категории на диаграмме — в «Прочем»
    _byCategory = {};
    for (final e in db.categoryExpensesFor(transactions).entries) {
      final category = Category.fromString(e.key);
      _byCategory[category] = (_byCategory[category] ?? 0) + e.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_income == 0 && _expense == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BudgetExpenseRatioCard(
        totalIncome: _income,
        totalExpense: _expense,
        categoryExpenses: _byCategory,
      ),
    );
  }
}
