import 'dart:async';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/screens/profile_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'add_transaction_sheet.dart';
import 'auth_screen.dart';

/// Главный экран: баланс за выбранный период и список операций.
///
/// [onAuthenticated] вызывается после успешного входа/регистрации в
/// [AuthScreen] и поднимает данные пользователя в [MainShell], который
/// передаёт их дальше в экран профиля.
///
/// [onOpenProfile] просит [MainShell] переключиться на вкладку профиля —
/// так залогиненный пользователь попадает в профиль с нижней навигацией,
/// а не в отдельный экран поверх стека.
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
  }

  @override
  void dispose() {
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

    // 1. Загружаем итоги месяца (только если это не дозагрузка,
    //    так как итоги для месяца не меняются от пагинации списка)
    if (!isLoadMore) {
      final totals =
          LocalDbService.instance.getMonthTotals(_selectedMonth, _selectedYear);
      _totalIncome = totals['income'] ?? 0;
      _totalExpense = totals['expense'] ?? 0;
      _totalBalance = _totalIncome - _totalExpense;
    }

    // 2. Загружаем страницу транзакций
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

    // 3. Группируем (обновляем существующую карту)
    final Map<DateTime, Map<Category, List<Transaction>>> grouped =
        isLoadMore ? Map.from(_groupedTransactions) : {};

    for (var t in newBatch) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(t.category, () => []);
      grouped[date]![t.category]!.add(t);
    }

    // Сортировка дат (только если добавили новые)
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
      AppAlerts.warning(context, context.l10n.sync_login_required);
      return;
    }

    // Проверка интернета перед синхронизацией
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        AppAlerts.noInternet(context);
      }
      return;
    }

    try {
      AppLogger.d('[Dashboard] Forced pull-to-refresh transactions sync');

      // 1. Выгружаем отложенные удаления
      final pendingTransactions = PendingDeletionsStore.instance.transactionIds;
      if (pendingTransactions.isNotEmpty) {
        final done = <String>[];
        for (final serverId in pendingTransactions) {
          try {
            await ApiService.instance.deleteTransaction(serverId);
            done.add(serverId);
          } catch (e) {
            AppLogger.w('[Dashboard] Pending delete failed: $e');
          }
        }
        await PendingDeletionsStore.instance.removeTransactions(done);
      }

      // 2. Выгружаем локальные изменения и скачиваем новые данные в одном вызове syncAll
      await ApiService.instance.syncAll();

      _loadTransactions();
      if (mounted) {
        AppAlerts.success(context, context.l10n.sync_success);
      }
    } catch (e) {
      AppLogger.e('[Dashboard] Sync error: $e');
      if (mounted) {
        AppErrorHandler.show(context, e, title: context.l10n.cloud);
      }
    }
  }

  /// Удаляет запись и локально, и на сервере.
  ///
  /// Через ApiService, а не напрямую через LocalDbService: удалённая только
  /// локально запись осталась бы на сервере и вернулась при следующей
  /// синхронизации. Если сети нет, удаление встанет в очередь и повторится
  /// позже — поэтому ответа не ждём и список обновляем сразу.
  void _deleteTransaction(Transaction transaction) {
    ApiService.instance.deleteTransactionEverywhere(transaction);
    _loadTransactions();

    AppAlerts.info(context, context.l10n.transaction_deleted);
  }

  /// Открывает форму добавления новой записи или редактирования существующей.
  void _openTransactionSheet([Transaction? transaction]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(transactionToEdit: transaction),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  /// Открывает экран входа/регистрации; при успешном завершении сообщает
  /// данные пользователя наверх через [DashboardScreen.onAuthenticated]
  /// и перенаправляет пользователя в профиль.
  void _openAuthScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (!mounted) return;

    // Именно _loadTransactions, а не пустой setState: вход запускает полную
    // синхронизацию, и в локальной базе теперь могут быть записи, приехавшие
    // с сервера (после переустановки приложения — вообще все).
    _loadTransactions();

    // AuthScreen просто закрывается после успешного входа, поэтому результат
    // читаем из ApiService — там уже лежат токен и профиль пользователя.
    if (ApiService.instance.isAuthenticated) {
      widget.onAuthenticated?.call(
        ApiService.instance.email ?? '',
        ApiService.instance.userName ?? '',
      );
      _openProfile();
    }
  }

  /// Переход в профиль: по возможности переключаем вкладку в [MainShell],
  /// иначе (экран используется отдельно) открываем профиль поверх стека.
  void _openProfile() async {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userEmail: ApiService.instance.email ?? '',
          userName: ApiService.instance.userName ?? '',
          onLogout: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  void _showPeriodPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            top: 10,
            left: 24,
            right: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                context.l10n.select_period,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      borderRadius: BorderRadius.circular(24),
                      alignment: Alignment.center,
                      decoration: InputDecoration(
                        labelText: context.l10n.month_label,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      items: List.generate(12, (index) {
                        final monthValue = index + 1;
                        final isCurrentMonth =
                            monthValue == DateTime.now().month &&
                                tempYear == DateTime.now().year;

                        return DropdownMenuItem(
                          value: monthValue,
                          alignment: Alignment.center,
                          child: Text(
                            LanguageManager.monthsNames[index],
                            style: TextStyle(
                              fontWeight: isCurrentMonth
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentMonth
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setModalState(() => tempMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      borderRadius: BorderRadius.circular(24),
                      alignment: Alignment.center,
                      decoration: InputDecoration(
                        labelText: context.l10n.year_label,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      items: List.generate(11, (index) {
                        final yearValue = DateTime.now().year + index;
                        final isCurrentYear = yearValue == DateTime.now().year;
                        return DropdownMenuItem(
                          value: yearValue,
                          alignment: Alignment.center,
                          child: Text(
                            '$yearValue',
                            style: TextStyle(
                              fontWeight: isCurrentYear
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentYear
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setModalState(() => tempYear = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                      _loadTransactions();
                    });
                    Navigator.pop(context);
                  },
                  child: Text(context.l10n.continue_btn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentMonthName = LanguageManager.monthsNames[_selectedMonth - 1];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: GestureDetector(
          onTap: _showPeriodPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '$currentMonthName $_selectedYear',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurface),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ApiService.instance.isAuthenticated
                ? GestureDetector(
                    onTap: _openProfile,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      backgroundImage: ApiService.instance.avatarUrl != null
                          ? NetworkImage(ApiService.instance.avatarUrl!)
                          : null,
                      child: ApiService.instance.avatarUrl == null
                          ? Icon(Icons.person,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                  )
                : TextButton(
                    onPressed: _openAuthScreen,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        context.l10n.login_or_register,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
          )
        ],
      ),
      body: SafeArea(
        child: CustomPullToRefresh(
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!ApiService.instance.isAuthenticated)
                        Builder(
                          builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.amber.withValues(alpha: 0.3)
                                        : Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${context.l10n.guest_mode} (${context.l10n.cloud_not_connected.toLowerCase()})',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.amber.shade200
                                            : Colors.amber.shade900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      BalanceCard(
                        balance: _totalBalance,
                        income: _totalIncome,
                        expense: _totalExpense,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.balance,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 12),
                      if (_transactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child: Center(
                            child: Text(
                              context.l10n.no_transactions,
                              style: const TextStyle(color: Colors.grey),
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

                        return _buildDayGroup(
                          date,
                          categories,
                          showHintOnFirstCategory:
                              index == 0 && _shouldShowSwipeHint,
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionSheet(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildDayGroup(
      DateTime date, Map<Category, List<Transaction>> categories,
      {bool showHintOnFirstCategory = false}) {
    final formattedDate = LanguageManager.formatDayMonth(date);
    final isToday = DateTime.now().year == date.year &&
        DateTime.now().month == date.month &&
        DateTime.now().day == date.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            isToday ? '${context.l10n.today}, $formattedDate' : formattedDate,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ...categories.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final categoryEntry = entry.value;
          return _buildCategoryGroup(
            categoryEntry.key,
            categoryEntry.value,
            showHintOnFirstTransaction: showHintOnFirstCategory && idx == 0,
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCategoryGroup(Category category, List<Transaction> transactions,
      {bool showHintOnFirstTransaction = false}) {
    final total = transactions.fold<double>(0, (sum, t) {
      return t.type == TransactionType.income ? sum + t.amount : sum - t.amount;
    });

    IconData categoryIcon = Icons.category;
    Color categoryColor = Colors.grey.shade400;
    Color bgColor = Colors.grey.shade50;

    if (category == Category.food) {
      categoryIcon = Icons.shopping_cart;
      categoryColor = Colors.orange.shade400;
      bgColor = Colors.orange.shade50;
    } else if (category == Category.transport) {
      categoryIcon = Icons.directions_bus;
      categoryColor = Colors.blue.shade400;
      bgColor = Colors.blue.shade50;
    } else if (category == Category.salary) {
      categoryIcon = Icons.monetization_on;
      categoryColor = Colors.teal.shade400;
      bgColor = Colors.teal.shade50;
    } else if (category == Category.entertainment) {
      categoryIcon = Icons.movie;
      categoryColor = Colors.purple.shade400;
      bgColor = Colors.purple.shade50;
    } else if (category == Category.health) {
      categoryIcon = Icons.medical_services;
      categoryColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (category == Category.shopping) {
      categoryIcon = Icons.shopping_bag;
      categoryColor = Colors.pink.shade400;
      bgColor = Colors.pink.shade50;
    } else if (category == Category.subscriptions) {
      categoryIcon = Icons.subscriptions;
      categoryColor = Colors.indigo.shade400;
      bgColor = Colors.indigo.shade50;
    } else if (category == Category.freelance) {
      categoryIcon = Icons.laptop_mac;
      categoryColor = Colors.amber.shade700;
      bgColor = Colors.amber.shade50;
    } else if (category == Category.investments) {
      categoryIcon = Icons.trending_up;
      categoryColor = Colors.green.shade600;
      bgColor = Colors.green.shade50;
    } else if (category == Category.transfers) {
      categoryIcon = Icons.swap_horiz;
      categoryColor = Colors.cyan.shade600;
      bgColor = Colors.cyan.shade50;
    } else if (category == Category.cashback) {
      categoryIcon = Icons.savings;
      categoryColor = Colors.teal.shade600;
      bgColor = Colors.teal.shade50;
    } else if (category == Category.sales) {
      categoryIcon = Icons.sell;
      categoryColor = Colors.deepOrange.shade400;
      bgColor = Colors.deepOrange.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        key: Key('expansion_${category.name}_$showHintOnFirstTransaction'),
        initiallyExpanded: showHintOnFirstTransaction,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(categoryIcon, color: categoryColor, size: 20),
        ),
        title: Text(
          category.getLocalizedName(context),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: CurrencyFormatter.formatText(
            total,
            textAlign: TextAlign.end,
            showSign: true,
            showSymbol: false,
            useFittedBox: true,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: total >= 0
                  ? Colors.teal.shade700
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        children: transactions.asMap().entries.map((entry) {
          return _buildTransactionItem(
            entry.value,
            isFirst: entry.key == 0,
            showHint: showHintOnFirstTransaction && entry.key == 0,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction,
      {bool isFirst = false, bool showHint = false}) {
    final isExpense = transaction.type == TransactionType.expense;

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).colorScheme.error,
      child: const Icon(Icons.delete, color: Colors.white),
    );

    Widget item = Dismissible(
      key: Key(transaction.localId.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteTransaction(transaction);
      },
      background: background,
      child: Material(
        color: Theme.of(context).cardColor,
        child: ListTile(
          onTap: () => _openTransactionSheet(transaction),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          title: Text(
            transaction.description.isEmpty
                ? context.l10n.no_description
                : transaction.description,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: CurrencyFormatter.formatText(
              isExpense ? -transaction.amount : transaction.amount,
              textAlign: TextAlign.end,
              showSign: true,
              showSymbol: false,
              useFittedBox: true,
              style: TextStyle(
                fontSize: 14,
                color: isExpense ? Colors.grey.shade700 : Colors.teal.shade600,
              ),
            ),
          ),
        ),
      ),
    );

    if (isFirst) {
      return SwipeHintWrapper(
        showHint: showHint,
        background: background,
        onHintShown: () {
          PreferencesService.instance.recordHintShown('dashboard');
          _swipeHintDismissTimer?.cancel();
          _swipeHintDismissTimer =
              Timer(const Duration(milliseconds: 2000), () {
            if (mounted) setState(() => _shouldShowSwipeHint = false);
          });
        },
        child: item,
      );
    }

    return item;
  }
}
