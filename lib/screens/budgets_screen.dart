import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/budgets/budgets.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';

/// Вкладка «Бюджет»: карточка бюджета месяца (сколько можно тратить в день)
/// и лимиты по категориям.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with ReloadWhenVisible {
  int get _selectedMonth => SelectedPeriodService.instance.period.month;
  int get _selectedYear => SelectedPeriodService.instance.period.year;

  List<Budget> _budgets = [];

  /// Лимиты прошлого месяца — источник копирования, пока в выбранном
  /// месяце лимитов нет.
  List<Budget> _previousBudgets = const [];

  /// Расходы по категориям в базовой валюте — для сводки месяца.
  Map<String, double> _categoryExpenses = {};

  /// Расходы по категориям в валютах лимитов, отличных от базовой.
  Map<Currency, Map<String, double>> _foreignExpenses = {};
  bool _shouldShowSwipeHint = false;

  /// Удалённые свайпом лимиты ждут здесь отмены.
  final _deletions = UndoableDeletions.budgets;

  /// Операции, скрытые в ожидании удаления на главной: в расходах по
  /// лимитам они уже не учитываются.
  final _transactionDeletions = UndoableDeletions.transactions;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _checkSwipeHint();
    CurrencyFormatter.currencyNotifier.addListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier.addListener(_onDataChanged);
    LocalDbService.transactionsChanged.addListener(_onDataChanged);
    _deletions.addListener(_onDataChanged);
    _transactionDeletions.addListener(_onDataChanged);
  }

  /// Перечитывает лимиты и расходы при смене валюты, периода или операций
  /// (в том числе добавленных с другой вкладки — тогда при показе вкладки).
  void _onDataChanged() => requestReload();

  @override
  void reloadData() => _loadBudgets();

  @override
  void dispose() {
    CurrencyFormatter.currencyNotifier.removeListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier
        .removeListener(_onDataChanged);
    LocalDbService.transactionsChanged.removeListener(_onDataChanged);
    _transactionDeletions.removeListener(_onDataChanged);
    // Очередь общая: при уходе с экрана скрытые лимиты удаляются сразу
    _deletions
      ..removeListener(_onDataChanged)
      ..flush();
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

  /// Загружает лимиты и расходы по категориям за выбранный месяц: один
  /// проход по операциям в базовой валюте и по одному на каждую другую
  /// валюту лимитов. Операции, скрытые в ожидании удаления, не учитываются.
  void _loadBudgets() {
    final db = LocalDbService.instance;
    final transactions = db
        .getTransactionsForPeriod(_selectedMonth, _selectedYear)
        .where((t) => !_transactionDeletions.isPending(t))
        .toList(growable: false);
    final catExpenses = db.categoryExpensesFor(transactions);
    final budgets = db
        .getBudgetsForPeriod(_selectedMonth, _selectedYear)
        .where((b) => !_deletions.isPending(b))
        .toList();
    final previous = SelectedPeriodService.instance.period.previous;
    final previousBudgets = budgets.isEmpty
        ? db
            .getBudgetsForPeriod(previous.month, previous.year)
            .where((b) => !_deletions.isPending(b))
            .toList(growable: false)
        : const <Budget>[];
    final base = CurrencyFormatter.currentCurrency;
    final foreign = <Currency, Map<String, double>>{};
    for (final currency in budgets.map((b) => b.currency).toSet()) {
      if (currency == base) continue;
      foreign[currency] = db.categoryExpensesFor(transactions, currency);
    }
    setState(() {
      _budgets = budgets;
      _previousBudgets = previousBudgets;
      _categoryExpenses = catExpenses;
      _foreignExpenses = foreign;
    });
  }

  /// Потрачено по лимиту в его валюте.
  double _spentFor(Budget budget) {
    final expenses = _foreignExpenses[budget.currency] ?? _categoryExpenses;
    return expenses[budget.dbCategory] ?? 0;
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
      if (mounted) {
        _loadBudgets();
        AppAlerts.success(context, context.l10n.sync_success);
      }
    } catch (e) {
      if (mounted) {
        _loadBudgets();
        AppErrorHandler.show(context, e, title: context.l10n.sync_error);
      }
    }
  }

  /// Скрывает лимит и предлагает отменить удаление, пока виден тост.
  void _deleteBudget(Budget budget) {
    _deletions.schedule(budget);
    AppAlerts.showToast(
      context,
      message: context.l10n.budget_deleted,
      duration: _deletions.delay,
      actionLabel: context.l10n.undo_action,
      onAction: () => _deletions.undo(budget),
    );
  }

  /// Копирует лимиты прошлого месяца в пустой выбранный месяц.
  void _copyPreviousLimits() {
    final period = SelectedPeriodService.instance.period;
    // Источник берётся до отмены удалений: отмена перезагружает экран, и
    // месяц с вернувшимся лимитом уже не пустой — список источника пуст.
    final source = _previousBudgets;
    final categories = {for (final b in source) b.dbCategory};
    // Удалённые свайпом лимиты этого месяца ещё ждут отмены, а копия ляжет
    // в их строки: удаление отменяется, иначе через несколько секунд оно
    // стёрло бы копию вместе с серверной записью.
    _deletions.undoWhere((b) =>
        b.month == period.month &&
        b.year == period.year &&
        categories.contains(b.dbCategory));
    LocalDbService.instance.copyBudgets(source, period);
    ApiService.instance.pushLocalChangesInBackground();
    _loadBudgets();
  }

  void _openAddBudgetSheet([Budget? budgetToEdit]) {
    AddBudgetSheet.show(
      context,
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
      budgetToEdit: budgetToEdit,
      // Новый лимит может лечь в строку, удалённую свайпом (удаление
      // отменится). Правка же переносит свою запись в другую категорию, и
      // строка, ждущая удаления, дала бы второй лимит той же категории —
      // такие категории при правке не предлагаются.
      limitedCategories: {
        for (final b in budgetToEdit == null
            ? _budgets
            : LocalDbService.instance
                .getBudgetsForPeriod(_selectedMonth, _selectedYear))
          b.category,
      },
      onSaved: _loadBudgets,
      onDelete: budgetToEdit == null ? null : () => _deleteBudget(budgetToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = AppColors.of(context).shellBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: Text(
          context.l10n.finances,
          style: AppTypography.screenTitle(context),
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
                      MonthBudgetCard(
                        summary: MonthBudgetSummary.calculate(
                          budgets: _budgets,
                          spentByCategory: _categoryExpenses,
                          period: SelectedPeriodService.instance.period,
                        ),
                        onAddLimit: () => _openAddBudgetSheet(),
                        copyLimitsFrom: _previousBudgets.isEmpty
                            ? null
                            : SelectedPeriodService.instance.period.previous,
                        onCopyLimits: _previousBudgets.isEmpty
                            ? null
                            : _copyPreviousLimits,
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
                          currentSpent: _spentFor(b),
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
