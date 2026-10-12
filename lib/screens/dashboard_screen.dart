import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/budgets/budgets.dart';
import '../widgets/dashboard/dashboard.dart';
import '../widgets/widgets.dart';
import 'add_transaction_sheet.dart';
import 'auth_screen.dart';

/// Главный экран: баланс за выбранный период и список операций.
class DashboardScreen extends StatefulWidget {
  final void Function(String email, String name)? onAuthenticated;
  final VoidCallback? onOpenProfile;

  const DashboardScreen({super.key, this.onAuthenticated, this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<Transaction> _transactions = [];
  Map<DateTime, Map<Category, List<Transaction>>> _groupedTransactions = {};
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalBalance = 0;

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
    CurrencyFormatter.currencyNotifier.addListener(_onCurrencyChanged);
  }

  void _onCurrencyChanged() {
    if (mounted) {
      _loadTransactions();
    }
  }

  @override
  void dispose() {
    CurrencyFormatter.currencyNotifier.removeListener(_onCurrencyChanged);
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

  /// Перечитывает транзакции из локальной БД с использованием пагинации
  /// и фильтрации на уровне базы данных.
  void _loadTransactions({bool isLoadMore = false}) {
    if (_isLoading) return;

    if (!isLoadMore) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _transactions.clear();
        _groupedTransactions = {};
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    if (!isLoadMore) {
      final totals =
          LocalDbService.instance.getMonthTotals(_selectedMonth, _selectedYear);
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

    _transactions.addAll(newBatch);
    _offset += newBatch.length;

    final Map<DateTime, Map<Category, List<Transaction>>> grouped =
        isLoadMore ? Map.from(_groupedTransactions) : {};

    for (var t in newBatch) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(t.category, () => []);
      grouped[date]![t.category]!.add(t);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, Map<Category, List<Transaction>>> sortedGrouped = {};
    for (var date in sortedDates) {
      sortedGrouped[date] = grouped[date]!;
    }

    setState(() {
      _groupedTransactions = sortedGrouped;
      _isLoading = false;
    });
  }

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

  void _openTransactionSheet([Transaction? transaction]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        transactionToEdit: transaction,
      ),
    );
    if (mounted) _loadTransactions();
  }

  void _deleteTransaction(Transaction transaction) {
    ApiService.instance.deleteTransactionEverywhere(transaction);
    _loadTransactions();
    AppAlerts.info(context, context.l10n.transaction_deleted);
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

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          context.l10n.balance,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ApiService.instance.isAuthenticated
                ? GestureDetector(
                    onTap: _openProfile,
                    child: UserAvatar(
                      radius: 18,
                      avatarUrl: ApiService.instance.avatarUrl,
                      defaultIcon: Icons.person,
                    ),
                  )
                : TextButton(
                    onPressed: _openAuthScreen,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.login_btn_short,
                      maxLines: 1,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
          )
        ],
      ),
      body: CustomPullToRefresh(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          key: const PageStorageKey('dashboard_custom_scroll_view'),
          controller: _scrollController,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BalanceCard(
                      balance: _totalBalance,
                      income: _totalIncome,
                      expense: _totalExpense,
                    ),
                    BudgetPeriodSelector(
                      selectedMonth: _selectedMonth,
                      selectedYear: _selectedYear,
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      onMonthChanged: (month) {
                        setState(() {
                          _selectedMonth = month;
                          _loadTransactions();
                        });
                      },
                      onYearChanged: (year) {
                        setState(() {
                          _selectedYear = year;
                          _loadTransactions();
                        });
                      },
                    ),
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
            if (_transactions.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final date = _groupedTransactions.keys.elementAt(index);
                      final categories = _groupedTransactions[date]!;

                      return DayGroupWidget(
                        date: date,
                        categories: categories,
                        showHintOnFirstCategory:
                            index == 0 && _shouldShowSwipeHint,
                        onTransactionTap: _openTransactionSheet,
                        onTransactionDelete: _deleteTransaction,
                        onHintShown: () {
                          PreferencesService.instance
                              .recordHintShown('dashboard');
                          _swipeHintDismissTimer?.cancel();
                          _swipeHintDismissTimer = Timer(
                            const Duration(milliseconds: 2000),
                            () {
                              if (mounted) {
                                setState(() => _shouldShowSwipeHint = false);
                              }
                            },
                          );
                        },
                      );
                    },
                    childCount: _groupedTransactions.length,
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
                      color: colorScheme.primary,
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: LiquidGlassNavBar.fabBottomPadding(context),
        ),
        child: LiquidGlassFab(
          tooltip: context.l10n.new_transaction,
          onPressed: () => _openTransactionSheet(),
        ),
      ),
    );
  }
}
