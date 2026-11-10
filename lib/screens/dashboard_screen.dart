import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/dashboard/dashboard.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';
import 'record_actions.dart';
import 'auth_screen.dart';
import 'transaction_search_screen.dart';
import '../theme/theme.dart';

/// Главный экран: баланс за выбранный период и список операций.
class DashboardScreen extends StatefulWidget {
  final void Function(String email, String name)? onAuthenticated;
  final VoidCallback? onOpenProfile;

  const DashboardScreen({super.key, this.onAuthenticated, this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with ReloadWhenVisible {
  int get _selectedMonth => SelectedPeriodService.instance.period.month;
  int get _selectedYear => SelectedPeriodService.instance.period.year;

  /// Операции месяца без скрытых в ожидании удаления: читаются из базы
  /// одним запросом на перезагрузку, из них же считаются итоги.
  ///
  /// Месяц показывается целиком, без постраничной подгрузки: список дней
  /// и так строится лениво, а страницы резали день на границе (неполный
  /// итог дня), не подгружались, если первая страница влезала в экран, и
  /// сбрасывались при каждой правке.
  List<Transaction> _transactions = const [];
  Map<DateTime, List<Transaction>> _groupedTransactions = {};

  /// Ожидающие оплаты регулярные платежи месяца по дням и `serverId`
  /// записей «Оплачено» (значок ⟳ в строке).
  Map<DateTime, List<RecurringOccurrence>> _occurrencesByDay = {};
  Set<String> _recurringRecordIds = const {};
  List<DateTime> _days = const [];
  DashboardViewMode _viewMode = DashboardViewMode.days;
  List<CategoryMonthSummary> _categorySummaries = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalBalance = 0;

  /// Удалённые свайпом или из карточки операции ждут здесь отмены.
  final _deletions = UndoableDeletions.transactions;

  /// Остановленные регулярные платежи ждут здесь отмены.
  final _recurringDeletions = UndoableDeletions.recurringPayments;

  bool _shouldShowSwipeHint = false;
  Timer? _swipeHintDismissTimer;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _checkSwipeHint();
    CurrencyFormatter.currencyNotifier.addListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier.addListener(_onDataChanged);
    LocalDbService.transactionsChanged.addListener(_onDataChanged);
    LocalDbService.recurringPaymentsChanged.addListener(_onDataChanged);
    _deletions.addListener(_onDataChanged);
    _recurringDeletions.addListener(_onDataChanged);
  }

  /// Перечитывает данные при смене валюты, периода или операций
  /// (у скрытой вкладки — при её показе).
  void _onDataChanged() => requestReload();

  @override
  void reloadData() => _loadTransactions();

  @override
  void dispose() {
    CurrencyFormatter.currencyNotifier.removeListener(_onDataChanged);
    SelectedPeriodService.instance.periodNotifier
        .removeListener(_onDataChanged);
    LocalDbService.transactionsChanged.removeListener(_onDataChanged);
    LocalDbService.recurringPaymentsChanged.removeListener(_onDataChanged);
    _recurringDeletions.removeListener(_onDataChanged);
    // Очередь общая: при уходе с экрана скрытые операции удаляются сразу
    _deletions
      ..removeListener(_onDataChanged)
      ..flush();
    _swipeHintDismissTimer?.cancel();
    super.dispose();
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

  /// Перечитывает операции месяца и итоги. В режиме «По категориям» —
  /// итоги категорий, в режиме «По дням» — группы по дням.
  void _loadTransactions() {
    final all = _visibleMonthTransactions();
    final totals = LocalDbService.instance.totalsFor(all);
    final byCategories = _viewMode == DashboardViewMode.categories;
    final grouped = byCategories
        ? <DateTime, List<Transaction>>{}
        : DayGroupWidget.groupByDay(all);
    final recurring = RecurringPaymentService.instance;
    final period = SelectedPeriodService.instance.period;
    final occurrencesByDay = <DateTime, List<RecurringOccurrence>>{};
    if (!byCategories) {
      for (final o in recurring.occurrencesIn(period)) {
        if (!o.isPending || _recurringDeletions.isPending(o.payment)) continue;
        occurrencesByDay.putIfAbsent(o.dueDate, () => []).add(o);
      }
    }
    final recordIds = recurring.paidAround(period).keys.toSet();
    setState(() {
      _totalIncome = totals['income'] ?? 0;
      _totalExpense = totals['expense'] ?? 0;
      _totalBalance = _totalIncome - _totalExpense;
      _transactions = all;
      _categorySummaries =
          byCategories ? CategoryMonthSummary.fromTransactions(all) : const [];
      _groupedTransactions = grouped;
      _occurrencesByDay = occurrencesByDay;
      _recurringRecordIds = recordIds;
      _days = DayGroupWidget.mergeDays(grouped.keys, occurrencesByDay.keys);
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
      if (mounted) {
        _loadTransactions();
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
  Future<void> _openTransactionDetails(Transaction transaction) =>
      RecordActions.openTransaction(context, transaction,
          onDelete: _deleteTransaction);

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
        leading: IconButton(
          key: const ValueKey('dashboard_search'),
          tooltip: context.l10n.transaction_search_title,
          icon: const Icon(Icons.search_rounded),
          onPressed: () => TransactionSearchScreen.open(context),
        ),
        actions: [
          DashboardAccountAction(
            onLogin: _openAuthScreen,
            onOpenProfile: _openProfile,
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
                        if (_transactions.isEmpty && _days.isEmpty)
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
                            key: ValueKey('category_month_${summary.id}'),
                            summary: summary,
                            onTransactionTap: _openTransactionDetails,
                            onTransactionDelete: _deleteTransaction,
                          );
                        },
                        childCount: _categorySummaries.length,
                      ),
                    ),
                  ),
                if (_days.isNotEmpty && _viewMode == DashboardViewMode.days)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final date = _days[index];

                          return DayGroupWidget(
                            key: ValueKey('day_${date.millisecondsSinceEpoch}'),
                            date: date,
                            transactions:
                                _groupedTransactions[date] ?? const [],
                            occurrences: _occurrencesByDay[date] ?? const [],
                            onOccurrenceTap: (o) =>
                                RecordActions.openRecurring(context, o),
                            recurringRecordIds: _recurringRecordIds,
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
