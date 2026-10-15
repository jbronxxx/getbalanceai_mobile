import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../budgets/budget_expense_ratio_card.dart';

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

class _ExpenseStructureSectionState extends State<ExpenseStructureSection> {
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
  }

  @override
  void dispose() {
    SelectedPeriodService.instance.periodNotifier.removeListener(_reload);
    CurrencyFormatter.currencyNotifier.removeListener(_reload);
    LocalDbService.transactionsChanged.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(_load);
  }

  void _load() {
    if (!LocalDbService.isInitialized) return;
    final period = SelectedPeriodService.instance.period;
    final db = LocalDbService.instance;
    final totals = db.getMonthTotals(period.month, period.year);
    _income = totals['income'] ?? 0;
    _expense = totals['expense'] ?? 0;
    _byCategory = db.getCategoryExpensesForPeriod(period.month, period.year);
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
