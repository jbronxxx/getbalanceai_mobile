import 'dart:async';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/budgets/budgets.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';

/// Экран «Финансы»: инфографика расходов, лимиты по категориям за выбранный
/// месяц/год и выгрузка отчётов за период в CSV/PDF.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  int get _selectedMonth => SelectedPeriodService.instance.period.month;
  int get _selectedYear => SelectedPeriodService.instance.period.year;

  List<Budget> _budgets = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
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

  /// Загружает лимиты бюджета и данные расходов/доходов за выбранный период.
  void _loadBudgets() {
    final totals =
        LocalDbService.instance.getMonthTotals(_selectedMonth, _selectedYear);
    final catExpenses = LocalDbService.instance
        .getCategoryExpensesForPeriod(_selectedMonth, _selectedYear);
    setState(() {
      _budgets = LocalDbService.instance
          .getBudgetsForPeriod(_selectedMonth, _selectedYear);
      _totalIncome = totals['income'] ?? 0;
      _totalExpense = totals['expense'] ?? 0;
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

  Widget _buildEmptyBudgetsBubble(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFCBD5E1);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pie_chart_outline_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.l10n.no_budgets_subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg =
        isDark ? const Color(0xFF09090B) : const Color(0xFFEFF2F6);

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: Text(
          context.l10n.finances,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
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
                      BudgetExpenseRatioCard(
                        totalIncome: _totalIncome,
                        totalExpense: _totalExpense,
                        categoryExpenses: _categoryExpenses,
                      ),
                      ReportExportCard(
                        selectedMonth: _selectedMonth,
                        selectedYear: _selectedYear,
                      ),
                      BudgetsSectionHeader(
                        onAdd: () => _openAddBudgetSheet(),
                      ),
                    ],
                  ),
                ),
              ),
              if (_budgets.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: _buildEmptyBudgetsBubble(context),
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
