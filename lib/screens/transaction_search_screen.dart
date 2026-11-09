import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../utils/utils.dart';
import '../widgets/dashboard/dashboard.dart';
import '../widgets/widgets.dart';
import 'add_transaction_sheet.dart';

/// Поиск операций по всей истории: текст (описание или категория), тип и
/// валюта. Результаты по дням, как в ленте «Баланса»; тап открывает
/// карточку операции, свайп удаляет с отменой.
class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const TransactionSearchScreen(),
        ),
      );

  @override
  State<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen>
    with ReloadWhenVisible {
  final _queryController = TextEditingController();

  /// Удалённые свайпом или из карточки операции ждут здесь отмены (очередь
  /// общая с «Балансом»).
  final _deletions = UndoableDeletions.transactions;

  /// Вся история без скрытых в ожидании удаления; фильтруется в памяти.
  List<Transaction> _all = const [];
  TransactionSearch _search = const TransactionSearch();

  @override
  void initState() {
    super.initState();
    _load();
    CurrencyFormatter.currencyNotifier.addListener(_onDataChanged);
    LocalDbService.transactionsChanged.addListener(_onDataChanged);
    _deletions.addListener(_onDataChanged);
  }

  void _onDataChanged() => requestReload();

  @override
  void reloadData() => _load();

  @override
  void dispose() {
    CurrencyFormatter.currencyNotifier.removeListener(_onDataChanged);
    LocalDbService.transactionsChanged.removeListener(_onDataChanged);
    // Удаление здесь не ускоряется: тост с «Отменить» общий для приложения
    // и после ухода остаётся над «Балансом», а он тоже прячет операции в
    // ожидании удаления. Отмена из тоста вернёт операцию, без неё — удалится
    // по таймеру очереди.
    _deletions.removeListener(_onDataChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _load() {
    final all = LocalDbService.instance
        .getAllTransactions()
        .where((t) => !_deletions.isPending(t))
        .toList(growable: false);
    setState(() {
      _all = all;
      // Валюта, операций в которой не осталось, больше не фильтрует —
      // её чипа уже нет.
      final currency = _search.currency;
      if (currency != null &&
          !TransactionSearch.currenciesOf(all).contains(currency)) {
        _search = _search.copyWith(currency: () => null);
      }
    });
  }

  void _update(TransactionSearch search) => setState(() => _search = search);

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = _search.apply(_all, l10n);
    final grouped = DayGroupWidget.groupByDay(results);
    final days = grouped.keys.toList(growable: false);
    final currencies = TransactionSearch.currenciesOf(_all);

    return Scaffold(
      backgroundColor: AppColors.of(context).shellBackground,
      appBar: LiquidGlassAppBar(
        title: Text(
          l10n.transaction_search_title,
          style: AppTypography.screenTitle(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _QueryField(
              controller: _queryController,
              onChanged: (value) => _update(_search.copyWith(query: value)),
            ),
          ),
          const SizedBox(height: 12),
          _ChipRow(
            children: [
              for (final (type, label) in [
                (null, l10n.filter_all),
                (TransactionType.expense, l10n.filter_expenses),
                (TransactionType.income, l10n.filter_incomes),
              ])
                AppChoiceChip(
                  key: ValueKey('search_type_${type?.name ?? 'all'}'),
                  label: label,
                  selected: _search.type == type,
                  onTap: () => _update(_search.copyWith(type: () => type)),
                ),
            ],
          ),
          // Чипы валют — только когда есть из чего выбирать. Повторный тап
          // снимает фильтр.
          if (currencies.length > 1) ...[
            const SizedBox(height: 8),
            _ChipRow(
              children: [
                for (final currency in currencies)
                  AppChoiceChip(
                    key: ValueKey('search_currency_${currency.code}'),
                    label: currency.code,
                    selected: _search.currency == currency,
                    onTap: () => _update(_search.copyWith(
                      currency: () =>
                          _search.currency == currency ? null : currency,
                    )),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: results.isEmpty
                ? _NothingFound(text: l10n.search_nothing_found)
                : CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        sliver: SliverToBoxAdapter(
                          child: _ResultsSummary(results: results),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          MediaQuery.paddingOf(context).bottom + 16,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final date = days[index];
                              return DayGroupWidget(
                                key: ValueKey(
                                    'search_day_${date.millisecondsSinceEpoch}'),
                                date: date,
                                transactions: grouped[date]!,
                                showYear: true,
                                onTransactionTap: _openTransactionDetails,
                                onTransactionDelete: _deleteTransaction,
                              );
                            },
                            childCount: days.length,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueryField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _QueryField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: const ValueKey('transaction_search_field'),
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onTapOutside: unfocusOnTapOutside,
        decoration: InputDecoration(
          hintText: context.l10n.transaction_search_hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('transaction_search_clear'),
                  tooltip: context.l10n.search_clear,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Строка чипов с прокруткой вбок, если не помещается.
class _ChipRow extends StatelessWidget {
  final List<Widget> children;

  const _ChipRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Сколько найдено и на какие суммы (в базовой валюте).
class _ResultsSummary extends StatelessWidget {
  final List<Transaction> results;

  const _ResultsSummary({required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final totals = LocalDbService.instance.totalsFor(results);
    final income = totals['income'] ?? 0;
    final expense = totals['expense'] ?? 0;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Wrap(
        key: const ValueKey('transaction_search_summary'),
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(l10n.operations_count(results.length), style: style),
          if (income > 0)
            _SummaryAmount(
              label: l10n.type_income,
              amount: income,
              color: AppColors.of(context).accentText,
              style: style,
            ),
          if (expense > 0)
            _SummaryAmount(
              label: l10n.type_expense,
              amount: -expense,
              color: colorScheme.onSurface,
              style: style,
            ),
        ],
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final TextStyle? style;

  const _SummaryAmount({
    required this.label,
    required this.amount,
    required this.color,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: style),
        CurrencyFormatter.formatText(
          amount,
          showSign: true,
          style: style?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _NothingFound extends StatelessWidget {
  final String text;

  const _NothingFound({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
