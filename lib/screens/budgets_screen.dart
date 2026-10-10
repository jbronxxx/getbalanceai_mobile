import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

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
    if (canShow) {
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

    // Проверка интернета перед синхронизацией
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

  /// Открывает форму создания или редактирования лимита.
  void _showAddBudgetDialog([Budget? budgetToEdit]) {
    Category selectedCategory = budgetToEdit?.category ?? Category.food;
    final amountController = TextEditingController(
      text: budgetToEdit != null
          ? CurrencyFormatter.format(budgetToEdit.limitAmount,
              showSymbol: false)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  budgetToEdit != null
                      ? context.l10n.edit_budget_title
                      : context.l10n.add_budget_title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Category>(
                  value: selectedCategory,
                  borderRadius: BorderRadius.circular(24),
                  alignment: Alignment.centerLeft,
                  decoration: InputDecoration(
                    labelText: context.l10n.category_label,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  items: Category.expenseCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.getLocalizedName(context)),
                    );
                  }).toList(),
                  onChanged: budgetToEdit != null
                      ? null // Запрещаем менять категорию при редактировании, т.к. это ключ
                      : (val) {
                          if (val != null) {
                            setModalState(() => selectedCategory = val);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText:
                        '${context.l10n.budget_amount_hint} (${CurrencyFormatter.currentCurrency.localizedSymbol})',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final amount =
                          CurrencyFormatter.parseInput(amountController.text);
                      if (amount == null || amount <= 0) {
                        AppAlerts.warning(
                            context, context.l10n.alert_valid_amount);
                        return;
                      }

                      if (amount >
                          CurrencyFormatter.currentCurrency.maxAmount) {
                        AppAlerts.warning(context,
                            '${context.l10n.alert_amount_too_large} ${CurrencyFormatter.currentCurrency.code}');
                        return;
                      }

                      final spent = LocalDbService.instance.getSpentForCategory(
                          _selectedMonth, _selectedYear, selectedCategory.name);
                      final newBudget = Budget(
                        localId: budgetToEdit?.localId ?? 0,
                        serverId: budgetToEdit?.serverId,
                        dbCategory: selectedCategory.name,
                        limitAmount: amount,
                        month: _selectedMonth,
                        year: _selectedYear,
                        spent: spent,
                        remaining: amount - spent,
                        isModified: budgetToEdit?.serverId != null,
                      );
                      LocalDbService.instance.saveBudget(newBudget);
                      Navigator.pop(context);
                      _loadBudgets();
                    },
                    child: Text(
                        budgetToEdit != null
                            ? context.l10n.save_btn
                            : context.l10n.save_btn,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(context.l10n.budgets_title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, top: 16.0, bottom: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedMonth,
                        borderRadius: BorderRadius.circular(24),
                        alignment: Alignment.center,
                        decoration: InputDecoration(
                          labelText: context.l10n.month_label,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        items: List.generate(12, (index) {
                          final monthValue = index + 1;
                          final isCurrentMonth =
                              monthValue == DateTime.now().month &&
                                  _selectedYear == DateTime.now().year;

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
                                    ? const Color(0xFF0F766E)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMonth = val;
                              _loadBudgets();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedYear,
                        borderRadius: BorderRadius.circular(24),
                        alignment: Alignment.center,
                        decoration: InputDecoration(
                          labelText: context.l10n.year_label,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        items: List.generate(11, (index) {
                          final yearValue = DateTime.now().year - 5 + index;
                          final isCurrentYear =
                              yearValue == DateTime.now().year;
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
                                    ? const Color(0xFF0F766E)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedYear = val;
                              _loadBudgets();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, bottom: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final b = _budgets[index];
                      final currentSpent = LocalDbService.instance
                          .getSpentForCategory(
                              _selectedMonth, _selectedYear, b.dbCategory);
                      final progress = b.limitAmount > 0
                          ? (currentSpent / b.limitAmount).clamp(0.0, 1.0)
                          : 0.0;
                      final isExceeded = currentSpent > b.limitAmount;
                      final background = Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Theme.of(context).colorScheme.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      );

                      Widget item = Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isExceeded
                                    ? Colors.orange.shade200
                                    : Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: SwipeHintWrapper(
                              showHint: index == 0 && _shouldShowSwipeHint,
                              background: background,
                              onHintShown: () {
                                PreferencesService.instance
                                    .recordHintShown('budgets');
                              },
                              child: Dismissible(
                                key: Key('budget_${b.localId}'),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) => _deleteBudget(b),
                                background: background,
                                child: Material(
                                  color: Theme.of(context).cardColor,
                                  child: InkWell(
                                    onTap: () => _showAddBudgetDialog(b),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                  b.category.getLocalizedName(
                                                      context),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        CurrencyFormatter
                                                            .formatText(
                                                          currentSpent,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isExceeded
                                                                  ? Colors
                                                                      .orange
                                                                      .shade800
                                                                  : primaryTeal),
                                                        ),
                                                        Text(' / ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: isExceeded
                                                                    ? Colors
                                                                        .orange
                                                                        .shade800
                                                                    : primaryTeal)),
                                                        CurrencyFormatter
                                                            .formatText(
                                                          b.limitAmount,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isExceeded
                                                                  ? Colors
                                                                      .orange
                                                                      .shade800
                                                                  : primaryTeal),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          LinearProgressIndicator(
                                            value: progress,
                                            color: isExceeded
                                                ? Colors.orange.shade400
                                                : primaryTeal,
                                            backgroundColor:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.grey.shade800
                                                    : Colors.grey.shade100,
                                            minHeight: 8,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          if (isExceeded) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                                '${context.l10n.budget_exceeded} ${CurrencyFormatter.format(currentSpent - b.limitAmount, showSymbol: true)}!',
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.orange.shade300
                                                        : Colors
                                                            .orange.shade900,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600))
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      return item;
                    },
                    childCount: _budgets.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
