import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/budgets/budgets.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';

/// Вкладка «Бюджет»: карточка бюджета месяца (сколько можно тратить в день),
/// лимиты по категориям и выгрузка отчёта за месяц в CSV/PDF (кнопка в шапке).
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  int get _selectedMonth => SelectedPeriodService.instance.period.month;
  int get _selectedYear => SelectedPeriodService.instance.period.year;

  List<Budget> _budgets = [];
  Map<Category, double> _categoryExpenses = {};
  bool _shouldShowSwipeHint = false;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _checkSwipeHint();
    CurrencyFormatter.currencyNotifier.addListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier.addListener(_onDataChanged);
    LocalDbService.transactionsChanged.addListener(_onDataChanged);
  }

  /// Перечитывает лимиты и расходы при смене валюты, периода или операций
  /// (в том числе добавленных с другой вкладки).
  void _onDataChanged() {
    if (mounted) {
      _loadBudgets();
    }
  }

  @override
  void dispose() {
    CurrencyFormatter.currencyNotifier.removeListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier
        .removeListener(_onDataChanged);
    LocalDbService.transactionsChanged.removeListener(_onDataChanged);
    super.dispose();
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

  /// Загружает лимиты и расходы по категориям за выбранный месяц — одним
  /// проходом по операциям для карточки месяца и всех карточек лимитов.
  void _loadBudgets() {
    final catExpenses = LocalDbService.instance
        .getCategoryExpensesForPeriod(_selectedMonth, _selectedYear);
    setState(() {
      _budgets = LocalDbService.instance
          .getBudgetsForPeriod(_selectedMonth, _selectedYear);
      _categoryExpenses = catExpenses;
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
    unawaited(
      ApiService.instance.deleteBudgetEverywhere(budget).catchError(
        (Object e, StackTrace s) {
          AppLogger.w('[Budgets] Delete budget everywhere failed', e, s);
        },
      ),
    );
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
    final scaffoldBg = AppColors.of(context).shellBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: Text(
          context.l10n.finances,
          style: AppTypography.screenTitle(context),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ReportExportAction(
              selectedMonth: _selectedMonth,
              selectedYear: _selectedYear,
            ),
          ),
        ],
      ),
      body: ScreenBodyCard(
        child: CustomPullToRefresh(
          topPadding: LiquidGlassAppBar.topContentPadding(context),
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            key: const PageStorageKey('budgets_custom_scroll_view'),
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: LiquidGlassAppBar.topContentPadding(context) + 8.0,
                    left: 16.0,
                    right: 16.0,
                    bottom: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PeriodSwitcher(),
                      MonthBudgetCard(
                        summary: MonthBudgetSummary.calculate(
                          budgets: _budgets,
                          spentByCategory: _categoryExpenses,
                          period: SelectedPeriodService.instance.period,
                        ),
                        onAddLimit: () => _openAddBudgetSheet(),
                      ),
                      if (_budgets.isNotEmpty)
                        BudgetsSectionHeader(
                          onAdd: () => _openAddBudgetSheet(),
                        ),
                    ],
                  ),
                ),
              ),
              if (_budgets.isNotEmpty)
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

                        return BudgetItemCard(
                          budget: b,
                          currentSpent: _categoryExpenses[b.category] ?? 0,
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: LiquidGlassNavBar.bottomContentPadding(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
