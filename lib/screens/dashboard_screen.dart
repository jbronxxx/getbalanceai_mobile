import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/dashboard/dashboard.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';
import 'add_transaction_sheet.dart';
import 'auth_screen.dart';
import '../theme/theme.dart';

/// Главный экран: баланс за выбранный период и список операций.
class DashboardScreen extends StatefulWidget {
  final void Function(String email, String name)? onAuthenticated;
  final VoidCallback? onOpenProfile;

  const DashboardScreen({super.key, this.onAuthenticated, this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int get _selectedMonth => SelectedPeriodService.instance.period.month;
  int get _selectedYear => SelectedPeriodService.instance.period.year;

  final List<Transaction> _transactions = [];
  Map<DateTime, List<Transaction>> _groupedTransactions = {};
  List<DateTime> _days = const [];
  DashboardViewMode _viewMode = DashboardViewMode.days;
  List<CategoryMonthSummary> _categorySummaries = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalBalance = 0;

  /// Удалённые свайпом или из карточки операции ждут здесь отмены.
  final _deletions = UndoableDeletions.transactions();

  bool _shouldShowSwipeHint = false;
  Timer? _swipeHintDismissTimer;

  // Параметры пагинации
  final ScrollController _scrollController = ScrollController();
  int _offset = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _checkSwipeHint();
    _scrollController.addListener(_onScroll);
    CurrencyFormatter.currencyNotifier.addListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier.addListener(_onDataChanged);
    LocalDbService.transactionsChanged.addListener(_onDataChanged);
    _deletions.addListener(_onDataChanged);
  }

  /// Перечитывает данные при смене валюты, периода или операций.
  void _onDataChanged() {
    if (mounted) {
      _loadTransactions();
    }
  }

  @override
  void dispose() {
    CurrencyFormatter.currencyNotifier.removeListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier
        .removeListener(_onDataChanged);
    LocalDbService.transactionsChanged.removeListener(_onDataChanged);
    _deletions
      ..removeListener(_onDataChanged)
      ..dispose();
    _swipeHintDismissTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoading) {
      _loadTransactions(isLoadMore: true);
    }
  }

  void _checkSwipeHint() async {
    final canShow =
        await PreferencesService.instance.shouldShowSwipeHint('dashboard');
    if (!mounted) return;
    if (canShow) {
      setState(() {
        _shouldShowSwipeHint = true;
      });
    }
  }

  void _onViewModeChanged(DashboardViewMode mode) {
    if (mode == _viewMode) return;
    setState(() => _viewMode = mode);
    _loadTransactions();
  }

  /// Режим «По категориям»: итоги категорий за весь месяц, без пагинации —
  /// иначе итоги считались бы по первой странице.
  void _loadCategorySummaries() {
    final all = _visibleMonthTransactions();
    final totals = LocalDbService.instance.totalsFor(all);
    setState(() {
      _totalIncome = totals['income'] ?? 0;
      _totalExpense = totals['expense'] ?? 0;
      _totalBalance = _totalIncome - _totalExpense;
      _transactions
        ..clear()
        ..addAll(all);
      _categorySummaries = CategoryMonthSummary.fromTransactions(all);
      _groupedTransactions = {};
      _days = const [];
      _hasMore = false;
      _offset = all.length;
    });
  }

  /// Перечитывает транзакции из локальной БД с использованием пагинации
  /// и фильтрации на уровне базы данных.
  void _loadTransactions({bool isLoadMore = false}) {
    if (_isLoading) return;

    if (_viewMode == DashboardViewMode.categories) {
      if (!isLoadMore) _loadCategorySummaries();
      return;
    }

    if (!isLoadMore) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _transactions.clear();
        _groupedTransactions = {};
        _days = const [];
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    if (!isLoadMore) {
      final totals =
          LocalDbService.instance.totalsFor(_visibleMonthTransactions());
      _totalIncome = totals['income'] ?? 0;
      _totalExpense = totals['expense'] ?? 0;
      _totalBalance = _totalIncome - _totalExpense;
    }

    final newBatch = LocalDbService.instance.getTransactionsForPeriod(
      _selectedMonth,
      _selectedYear,
      limit: _pageSize,
      offset: _offset,
    );

    if (newBatch.length < _pageSize) {
      _hasMore = false;
    }

    // Смещение считается по базе, скрытые операции только не показываются
    _offset += newBatch.length;
    final visibleBatch =
        newBatch.where((t) => !_deletions.isPending(t)).toList(growable: false);
    _transactions.addAll(visibleBatch);

    final sortedGrouped = DayGroupWidget.groupByDay(
      visibleBatch,
      appendTo: isLoadMore ? _groupedTransactions : const {},
    );

    setState(() {
      _groupedTransactions = sortedGrouped;
      _days = sortedGrouped.keys.toList(growable: false);
      _isLoading = false;
    });
  }

  /// Операции месяца без скрытых в ожидании удаления.
  List<Transaction> _visibleMonthTransactions() => LocalDbService.instance
      .getTransactionsForPeriod(_selectedMonth, _selectedYear)
      .where((t) => !_deletions.isPending(t))
      .toList(growable: false);

  Future<void> _handleRefresh() async {
    if (!ApiService.instance.isAuthenticated) {
      _loadTransactions();
      AppAlerts.warning(context, context.l10n.sync_login_required);
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        _loadTransactions();
        AppAlerts.noInternet(context);
      }
      return;
    }

    try {
      AppLogger.d('[Dashboard] Starting syncAll via pull-to-refresh');
      await ApiService.instance.syncAll();
      _loadTransactions();
      if (mounted) {
        AppAlerts.success(context, context.l10n.sync_success);
      }
    } catch (e) {
      if (mounted) {
        _loadTransactions();
        AppErrorHandler.show(context, e, title: context.l10n.sync_error);
      }
    }
  }

  /// Тап по операции открывает карточку «только для чтения»; правка и
  /// удаление — её кнопками.
  Future<void> _openTransactionDetails(Transaction transaction) async {
    final action = await TransactionDetailsSheet.show(context, transaction);
    if (!mounted || action == null) return;
    switch (action) {
      case TransactionDetailsAction.edit:
        showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.transparent,
          builder: (context) => AddTransactionSheet(
            transactionToEdit: transaction,
          ),
        );
      case TransactionDetailsAction.delete:
        _deleteTransaction(transaction);
    }
  }

  /// Скрывает операцию и предлагает отменить удаление, пока виден тост.
  void _deleteTransaction(Transaction transaction) {
    _deletions.schedule(transaction);
    AppAlerts.showToast(
      context,
      message: context.l10n.transaction_deleted,
      duration: _deletions.delay,
      actionLabel: context.l10n.undo_action,
      onAction: () => _deletions.undo(transaction),
    );
  }

  void _openAuthScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openProfile() {
    widget.onOpenProfile?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final scaffoldBg = AppColors.of(context).shellBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: Text(
          context.l10n.balance,
          style: AppTypography.screenTitle(context),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DashboardAccountAction(
              onLogin: _openAuthScreen,
              onOpenProfile: _openProfile,
            ),
          ),
        ],
      ),
      body: ScreenBodyCard(
        child: CustomPullToRefresh(
          topPadding: LiquidGlassAppBar.topContentPadding(context),
          onRefresh: _handleRefresh,
          // Без растяжения у краёв (Android 12+): растянутая лента
          // перерисовывается со сглаживанием и даёт зернистую рябь под
          // размытым хэдером. Обратную связь у верхнего края даёт капсула
          // обновления.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              overscroll: false,
            ),
            child: CustomScrollView(
              key: const PageStorageKey('dashboard_custom_scroll_view'),
              controller: _scrollController,
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
                        BalanceCard(
                          balance: _totalBalance,
                          income: _totalIncome,
                          expense: _totalExpense,
                        ),
                        const SizedBox(height: 16),
                        DashboardViewSwitcher(
                          mode: _viewMode,
                          onChanged: _onViewModeChanged,
                        ),
                        const SizedBox(height: 8),
                        if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40.0),
                            child: Center(
                              child: Text(
                                context.l10n.no_transactions,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_transactions.isNotEmpty &&
                    _viewMode == DashboardViewMode.categories)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final summary = _categorySummaries[index];
                          return CategoryMonthGroup(
                            key: ValueKey(
                                'category_month_${summary.category.name}'),
                            summary: summary,
                            onTransactionTap: _openTransactionDetails,
                            onTransactionDelete: _deleteTransaction,
                          );
                        },
                        childCount: _categorySummaries.length,
                      ),
                    ),
                  ),
                if (_transactions.isNotEmpty &&
                    _viewMode == DashboardViewMode.days)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final date = _days[index];

                          return DayGroupWidget(
                            key: ValueKey('day_${date.millisecondsSinceEpoch}'),
                            date: date,
                            transactions: _groupedTransactions[date]!,
                            showHintOnFirstTransaction:
                                index == 0 && _shouldShowSwipeHint,
                            onTransactionTap: _openTransactionDetails,
                            onTransactionDelete: _deleteTransaction,
                            onHintShown: () {
                              PreferencesService.instance
                                  .recordHintShown('dashboard');
                              _swipeHintDismissTimer?.cancel();
                              _swipeHintDismissTimer = Timer(
                                const Duration(milliseconds: 2000),
                                () {
                                  if (mounted) {
                                    setState(
                                        () => _shouldShowSwipeHint = false);
                                  }
                                },
                              );
                            },
                          );
                        },
                        childCount: _days.length,
                      ),
                    ),
                  ),
                if (_isLoading && _transactions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.of(context).accentText,
                        ),
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
      ),
    );
  }
}
