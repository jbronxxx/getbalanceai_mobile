import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/budgets/budgets.dart';
import '../widgets/widgets.dart';

/// Экран лимитов бюджета: показывает установленные лимиты по категориям за
/// выбранный месяц/год и позволяет добавить новый лимит.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Budget> _budgets = [];
  bool _shouldShowSwipeHint = false;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _checkSwipeHint();
  }

  void _checkSwipeHint() async {
    final canShow =
        await PreferencesService.instance.shouldShowSwipeHint('budgets');
    if (canShow && mounted) {
      setState(() {
        _shouldShowSwipeHint = true;
      });
    }
  }

  /// Загружает лимиты бюджета за текущие выбранные месяц/год.
  void _loadBudgets() {
    setState(() {
      _budgets = LocalDbService.instance
          .getBudgetsForPeriod(_selectedMonth, _selectedYear);
    });
  }

  Future<void> _handleRefresh() async {
    if (!ApiService.instance.isAuthenticated) {
      _loadBudgets();
      AppAlerts.warning(context, context.l10n.sync_login_required);
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        _loadBudgets();
        AppAlerts.noInternet(context);
      }
      return;
    }

    try {
      AppLogger.d('[Budgets] Starting syncAll via pull-to-refresh');
      await ApiService.instance.syncAll();
      _loadBudgets();
      if (mounted) {
        AppAlerts.success(context, context.l10n.sync_success);
      }
    } catch (e) {
      if (mounted) {
        _loadBudgets();
        AppErrorHandler.show(context, e, title: context.l10n.sync_error);
      }
    }
  }

  /// Удаляет лимит бюджета локально и на сервере.
  void _deleteBudget(Budget budget) {
    ApiService.instance.deleteBudgetEverywhere(budget);
    _loadBudgets();
    AppAlerts.info(context, context.l10n.budget_deleted);
  }

  void _openAddBudgetSheet([Budget? budgetToEdit]) {
    AddBudgetSheet.show(
      context,
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
      budgetToEdit: budgetToEdit,
      onSaved: _loadBudgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          context.l10n.budgets_title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomPullToRefresh(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: BudgetPeriodSelector(
                selectedMonth: _selectedMonth,
                selectedYear: _selectedYear,
                onMonthChanged: (val) {
                  setState(() {
                    _selectedMonth = val;
                    _loadBudgets();
                  });
                },
                onYearChanged: (val) {
                  setState(() {
                    _selectedYear = val;
                    _loadBudgets();
                  });
                },
              ),
            ),
            if (_budgets.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      context.l10n.no_budgets_subtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 16.0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final b = _budgets[index];
                      final currentSpent = LocalDbService.instance
                          .getSpentForCategory(
                              _selectedMonth, _selectedYear, b.dbCategory);

                      return BudgetItemCard(
                        budget: b,
                        currentSpent: currentSpent,
                        isFirst: index == 0,
                        showSwipeHint: index == 0 && _shouldShowSwipeHint,
                        onTap: () => _openAddBudgetSheet(b),
                        onDelete: () => _deleteBudget(b),
                        onHintShown: () {
                          PreferencesService.instance
                              .recordHintShown('budgets');
                        },
                      );
                    },
                    childCount: _budgets.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddBudgetSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
