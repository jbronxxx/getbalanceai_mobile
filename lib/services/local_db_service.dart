import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../objectbox.g.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';
import 'currency_exchange_service.dart';

/// Локальное хранилище приложения на базе ObjectBox.
///
/// Работает как singleton: инициализируется один раз в [main] через [init],
/// после чего доступ к базе идёт через [instance] — так экраны не тянут
/// зависимость на `main.dart` и не образуют циклический импорт
/// (main.dart -> screens -> main.dart), который был в предыдущей версии.
///
/// Хранит транзакции и лимиты бюджета в гостевом (офлайн) режиме; после
/// входа пользователя эти данные синхронизируются с бэкендом через
/// [ApiService].
class LocalDbService {
  static LocalDbService? _instance;
  static LocalDbService get instance {
    if (_instance == null) {
      throw StateError(
          'LocalDbService has not been initialized. Call init() first.');
    }
    return _instance!;
  }

  static set instance(LocalDbService? value) => _instance = value;
  static bool get isInitialized => _instance != null;

  /// Счётчик изменений данных: сохранение/удаление операции пользователем
  /// и завершённая загрузка изменений с сервера (`SyncService`).
  ///
  /// Вкладки, живущие в `IndexedStack`, подписываются на него, чтобы
  /// пересчитать данные. Отдельные записи синхронизации счётчик не меняют —
  /// иначе списки сбрасывали бы прокрутку на каждой записи; загрузка
  /// с сервера даёт один сигнал, и только если пришли изменения (не 304).
  static final ValueNotifier<int> transactionsChanged = ValueNotifier(0);

  late final Store _store;
  late final Box<Transaction> _transactionBox;
  late final Box<Budget> _budgetBox;

  LocalDbService._create(this._store) {
    _transactionBox = Box<Transaction>(_store);
    _budgetBox = Box<Budget>(_store);
    _migrateLegacyTransactions();
  }

  /// Проверяет наличие транзакций в локальной базе.
  bool get hasTransactions => !_transactionBox.isEmpty();

  /// Количество транзакций в локальной базе.
  int get transactionsCount => _transactionBox.count();

  /// Проверяет наличие бюджетов в локальной базе.
  bool get hasBudgets => !_budgetBox.isEmpty();

  /// Количество бюджетов в локальной базе.
  int get budgetsCount => _budgetBox.count();

  /// Мигрирует старые транзакции, созданные до внедрения мультивалютности или с устаревшей валютой RUB.
  /// Если baseAmount равен 0, заполняет его на основе amount и текущей валюты.
  /// Если currencyCode равен RUB, переводит его в текущую базовую валюту.
  void _migrateLegacyTransactions() {
    try {
      final legacyQuery = _transactionBox
          .query(Transaction_.baseAmount
              .lessOrEqual(0.0)
              .and(Transaction_.amount.greaterThan(0.0)))
          .build();
      final legacy = legacyQuery.find();
      legacyQuery.close();

      if (legacy.isNotEmpty) {
        final updated = <Transaction>[];
        for (final tx in legacy) {
          tx.baseAmount = tx.amount;
          tx.exchangeRate = 1.0;
          if (tx.currencyCode.isEmpty) {
            tx.currencyCode = 'USD';
          }
          updated.add(tx);
        }
        _transactionBox.putMany(updated);
        AppLogger.i(
          '[LocalDbService] Migrated ${updated.length} legacy transactions with baseAmount',
        );
      }

      final rubQuery = _transactionBox
          .query(Transaction_.currencyCode.equals('RUB', caseSensitive: false))
          .build();
      final rubTxs = rubQuery.find();
      rubQuery.close();

      if (rubTxs.isNotEmpty) {
        final currentCode = CurrencyFormatter.currentCurrency.code;
        for (final tx in rubTxs) {
          tx.currencyCode = currentCode;
        }
        _transactionBox.putMany(rubTxs);
        AppLogger.i(
          '[LocalDbService] Migrated ${rubTxs.length} legacy RUB transactions to $currentCode',
        );
      }
    } catch (e) {
      AppLogger.w('[LocalDbService] Legacy transactions migration skipped: $e');
    }
  }

  @visibleForTesting
  void migrateLegacyTransactionsForTesting() => _migrateLegacyTransactions();

  /// Открывает (или создаёт) файл базы данных в директории документов
  /// приложения и инициализирует [instance]. Должен быть вызван один раз
  /// при старте приложения, до первого обращения к [instance].
  static Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, "obx-finance");
    AppLogger.d('[LocalDbService] Opening store at $dbPath');
    final store = await openStore(directory: dbPath);
    instance = LocalDbService._create(store);
  }

  // --- Транзакции ---

  /// Возвращает транзакции за определенный месяц и год с поддержкой пагинации.
  /// Фильтрация происходит на уровне БД через диапазон миллисекунд.
  List<Transaction> getTransactionsForPeriod(int month, int year,
      {int? limit, int offset = 0}) {
    final startOfMonth = DateTime(year, month, 1).millisecondsSinceEpoch;
    final endOfMonth = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;

    final query = _transactionBox.query(
      Transaction_.dateMilliseconds.between(startOfMonth, endOfMonth),
    )..order(Transaction_.dateMilliseconds, flags: Order.descending);

    final q = query.build();
    if (limit != null) {
      q.limit = limit;
      q.offset = offset;
    }

    final results = q.find();
    q.close();
    return results;
  }

  /// Возвращает транзакции за период (границы из [ReportPeriod] включительно),
  /// от новых к старым. Фильтрация происходит на уровне БД.
  List<Transaction> getTransactionsInRange(ReportPeriod period) {
    final query = _transactionBox.query(
      Transaction_.dateMilliseconds.greaterOrEqual(period.startMilliseconds) &
          Transaction_.dateMilliseconds
              .lessThan(period.endExclusiveMilliseconds),
    )..order(Transaction_.dateMilliseconds, flags: Order.descending);

    final q = query.build();
    final results = q.find();
    q.close();
    return results;
  }

  /// Категории операций типа [type] за последние [window], от частых к редким.
  ///
  /// Используется формой операции, чтобы показать часто используемые
  /// категории первыми. Категории без операций в результат не попадают.
  List<Category> getFrequentCategories(
    TransactionType type, {
    Duration window = const Duration(days: 90),
    DateTime? now,
  }) {
    final since = (now ?? DateTime.now()).subtract(window);
    final q = _transactionBox
        .query(
          Transaction_.dbType.equals(type.name) &
              Transaction_.dateMilliseconds
                  .greaterOrEqual(since.millisecondsSinceEpoch),
        )
        .build();
    // Читаем только поле категории: форма открывается без загрузки
    // целых операций за весь период.
    final pq = q.property(Transaction_.dbCategory);
    final names = pq.find();
    pq.close();
    q.close();

    final counts = <Category, int>{};
    for (final name in names) {
      counts.update(Category.fromString(name), (c) => c + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted) e.key];
  }

  /// Считает общие итоги (доход и расход) за выбранный месяц с динамической
  /// конвертацией всех операций в текущую валюту аккаунта.
  Map<String, double> getMonthTotals(int month, int year,
          [Currency? targetCurrency]) =>
      totalsFor(getTransactionsForPeriod(month, year), targetCurrency);

  /// Итоги (доход и расход) по готовому списку операций — например, без
  /// скрытых в ожидании удаления.
  Map<String, double> totalsFor(Iterable<Transaction> transactions,
      [Currency? targetCurrency]) {
    final currency = targetCurrency ?? CurrencyFormatter.currentCurrency;
    final exchange = CurrencyExchangeService.instance;

    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      final converted = t.currency == currency
          ? t.amount
          : exchange.convert(t.amount, from: t.currency, to: currency);

      if (t.type == TransactionType.income) {
        income += converted;
      } else {
        expense += converted;
      }
    }

    return {'income': income, 'expense': expense};
  }

  /// Считает расходы по всем категориям за выбранный месяц с динамической
  /// конвертацией в текущую валюту аккаунта.
  Map<Category, double> getCategoryExpensesForPeriod(int month, int year,
      [Currency? targetCurrency]) {
    final transactions = getTransactionsForPeriod(month, year);
    final currency = targetCurrency ?? CurrencyFormatter.currentCurrency;
    final exchange = CurrencyExchangeService.instance;

    final Map<Category, double> result = {};

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        final converted = t.currency == currency
            ? t.amount
            : exchange.convert(t.amount, from: t.currency, to: currency);
        result[t.category] = (result[t.category] ?? 0.0) + converted;
      }
    }

    return result;
  }

  /// Возвращает все транзакции, отсортированные от новых к старым.
  List<Transaction> getAllTransactions() {
    final query = _transactionBox.query()
      ..order(Transaction_.dateMilliseconds, flags: Order.descending);
    final q = query.build();
    final results = q.find();
    q.close();
    return results;
  }

  void _ensureBaseAmount(Transaction transaction) {
    if (transaction.baseAmount <= 0.0 && transaction.amount > 0.0) {
      final rate =
          transaction.exchangeRate > 0.0 ? transaction.exchangeRate : 1.0;
      transaction.baseAmount = transaction.amount * rate;
    }
    if (transaction.currencyCode.isEmpty) {
      transaction.currencyCode = 'USD';
    }
  }

  /// Добавляет новую транзакцию (доход или расход) и возвращает её локальный ID.
  int addTransaction(Transaction transaction) {
    _ensureBaseAmount(transaction);
    return _transactionBox.put(transaction);
  }

  /// Сохраняет транзакцию: если `localId` уже существует — обновляет запись,
  /// иначе создаёт новую (поведение ObjectBox `Box.put`).
  void saveTransaction(Transaction transaction) {
    _ensureBaseAmount(transaction);
    _linkToExistingTransaction(transaction);
    final id = _transactionBox.put(transaction);
    AppLogger.d('[LocalDbService] Saved transaction localId: $id');
    transactionsChanged.value++;
  }

  /// Переносит на приехавшую с сервера транзакцию `localId` уже существующей
  /// локальной строки с тем же `serverId`, чтобы `put` её обновил, а не
  /// создал вторую.
  ///
  /// Без этого шага `put` вставил бы новую строку с тем же `serverId`, а он
  /// помечен `@Unique()` со стратегией по умолчанию `ConflictStrategy.fail` —
  /// то есть вставка не «перезаписала бы тихо», а бросила
  /// `UniqueViolationException` и оборвала синхронизацию.
  /// [claimed] — локальные `localId`, уже занятые другими записями в рамках
  /// одного прохода сверки; нужен, чтобы две серверные записи не «прилипли»
  /// к одной локальной строке.
  int? _linkToExistingTransaction(Transaction transaction,
      {Set<int>? claimed}) {
    final serverId = transaction.serverId;
    if (serverId == null) return null;

    final query =
        _transactionBox.query(Transaction_.serverId.equals(serverId)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      transaction.localId = existing.localId;
      claimed?.add(existing.localId);
      return existing.localId;
    }

    // Записи с таким serverId локально нет. Прежде чем вставлять новую
    // строку, ищем ещё не выгруженную запись с тем же содержимым: скорее
    // всего это та же самая операция, которой выгрузка не успела проставить
    // serverId (ответ `/sync/` вернулся неполным). Без этой проверки она
    // осталась бы в базе рядом с приехавшей копией — получился бы дубль, и
    // он же уехал бы на сервер при следующей выгрузке.
    final twin = _findUnsyncedTransactionTwin(transaction, claimed);

    if (twin != null) {
      transaction.localId = twin.localId;
      claimed?.add(twin.localId);
      return twin.localId;
    }

    return null;
  }

  /// Ищет невыгруженную локальную транзакцию, совпадающую с [remote] по
  /// содержимому: дата, категория, тип и сумма.
  ///
  /// Сумму сравниваем в Dart, а не в запросе: ObjectBox не умеет
  /// сопоставлять double на точное равенство.
  Transaction? _findUnsyncedTransactionTwin(
    Transaction remote,
    Set<int>? claimed,
  ) {
    final query = _transactionBox
        .query(Transaction_.serverId
            .isNull()
            .and(Transaction_.dateMilliseconds.equals(remote.dateMilliseconds))
            .and(Transaction_.dbCategory.equals(remote.dbCategory))
            .and(Transaction_.dbType.equals(remote.dbType)))
        .build();
    final candidates = query.find();
    query.close();

    for (final candidate in candidates) {
      final isClaimed = claimed?.contains(candidate.localId) ?? false;

      if (!isClaimed && candidate.amount == remote.amount) return candidate;
    }

    return null;
  }

  /// Удаляет транзакцию по локальному ID. Возвращает `true`, если запись
  /// была найдена и удалена.
  bool deleteTransaction(int id) {
    final removed = _transactionBox.remove(id);
    AppLogger.d('[LocalDbService] Removed transaction $id: $removed');
    if (removed) transactionsChanged.value++;
    return removed;
  }

  /// Массово сохраняет транзакции, которым только что проставили `serverId`
  /// по ответу `/sync/`.
  ///
  /// Без этого шага записи навсегда остаются «несинхронизированными» и
  /// выгружаются на сервер повторно при каждом входе и при каждом нажатии
  /// «Синхронизировать» — у транзакций нет естественного ключа, поэтому
  /// бэкенд создаёт на каждую отправку новую запись с новым UUID.
  void putTransactions(List<Transaction> transactions) {
    if (transactions.isEmpty) return;
    _transactionBox.putMany(transactions);
  }

  /// Возвращает транзакции, ещё не отправленные на сервер (`serverId == null`
  /// или `isModified == true`).
  /// Используется при синхронизации гостевых/локальных данных после входа/редактирования.
  List<Transaction> getUnsyncedTransactions() {
    final query = _transactionBox
        .query(Transaction_.serverId
            .isNull()
            .or(Transaction_.isModified.equals(true)))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Приводит локальные транзакции в соответствие с состоянием сервера.
  ///
  /// [remote] — ПОЛНЫЙ список транзакций пользователя с сервера (по всем
  /// периодам). Метод делает две вещи в одной транзакции записи:
  ///
  /// 1. upsert присланных записей по `serverId`;
  /// 2. удаление локальных записей, у которых `serverId` есть, но в [remote]
  ///    его нет, — значит запись удалили на сервере.
  ///
  /// Записи с `serverId == null` или `isModified == true` не удаляются
  /// и не перезаписываются устаревшими данными сервера: это локальные изменения,
  /// еще не выгруженные на бэкенд (см. [getUnsyncedTransactions]).
  ///
  /// Вызывать ТОЛЬКО с полным ответом сервера: для отфильтрованной или
  /// частичной выборки «нет в [remote]» не означает «удалено на сервере»,
  /// и сверка снесёт живые данные.
  ///
  /// Одна транзакция записи вместо `put` на каждую запись нужна и для
  /// скорости (на несколько месяцев гостевых данных это сотни строк), и для
  /// атомарности: оборвавшись на середине, метод не оставит базу в
  /// полуобновлённом состоянии.
  ///
  /// Возвращает число удалённых при сверке записей.
  int reconcileTransactions(List<Transaction> remote,
      {bool removeStale = true}) {
    return _store.runInTransaction(TxMode.write, () {
      final claimed = <int>{};
      final toPut = <Transaction>[];

      for (final transaction in remote) {
        final localId =
            _linkToExistingTransaction(transaction, claimed: claimed);
        if (localId != null) {
          final existing = _transactionBox.get(localId);
          if (existing != null && existing.isModified) {
            continue;
          }
        }
        toPut.add(transaction);
      }
      _transactionBox.putMany(toPut);

      if (!removeStale) {
        return 0;
      }

      final remoteIds =
          remote.map((t) => t.serverId).whereType<String>().toSet();

      final query = _transactionBox
          .query(Transaction_.serverId
              .notNull()
              .and(Transaction_.isModified.equals(false)))
          .build();
      final candidates = query.find();
      query.close();

      final stale = candidates
          .where((t) => !remoteIds.contains(t.serverId))
          .map((t) => t.localId)
          .toList();

      _transactionBox.removeMany(stale);
      return stale.length;
    });
  }

  /// Вставляет или обновляет транзакции с сервера без удаления отсутствующих записей.
  void upsertRemoteTransactions(List<Transaction> remote) {
    reconcileTransactions(remote, removeStale: false);
  }

  // --- Бюджеты ---

  /// Возвращает лимиты бюджета за конкретные месяц и год.
  List<Budget> getBudgetsForPeriod(int month, int year) {
    return _budgetBox
        .query(Budget_.month.equals(month).and(Budget_.year.equals(year)))
        .build()
        .find();
  }

  /// Возвращает все сохранённые лимиты бюджета — нужен для полной
  /// синхронизации с бэкендом.
  List<Budget> getAllBudgets() {
    return _budgetBox.getAll();
  }

  /// Сохраняет лимит бюджета. Если лимит на эту категорию за этот месяц/год
  /// уже существует — обновляет его вместо создания дубликата.
  void saveBudget(Budget budget) {
    _linkToExistingBudget(budget);
    final id = _budgetBox.put(budget);
    AppLogger.d('[LocalDbService] Saved budget localId: $id');
  }

  /// Ищет локальную строку, которую должен обновить этот лимит.
  ///
  /// Порядок проверок важен. Сначала `serverId` — это единственный ключ,
  /// который гарантированно указывает на ту же запись, даже если у неё на
  /// сервере поменяли категорию или период. Только если записи с таким
  /// `serverId` локально нет (или лимит создан офлайн и `serverId` пока
  /// пустой), сопоставляем по натуральному ключу `категория + месяц + год`.
  ///
  /// Раньше проверка по `serverId` отсутствовала, и при полной выгрузке с
  /// сервера строка находилась только по натуральному ключу — из-за чего
  /// `serverId` мог продублироваться между строками и `put` падал с
  /// `UniqueViolationException`.
  int? _linkToExistingBudget(Budget budget) {
    final serverId = budget.serverId;

    if (serverId != null) {
      final byServerId =
          _budgetBox.query(Budget_.serverId.equals(serverId)).build();
      final existing = byServerId.findFirst();
      byServerId.close();

      if (existing != null) {
        budget.localId = existing.localId;
        return existing.localId;
      }
    }

    final byPeriod = _budgetBox
        .query(
          Budget_.dbCategory
              .equals(budget.dbCategory)
              .and(Budget_.month.equals(budget.month))
              .and(Budget_.year.equals(budget.year)),
        )
        .build();
    final existing = byPeriod.findFirst();
    byPeriod.close();

    if (existing != null) {
      budget.localId = existing.localId;
      return existing.localId;
    }

    return null;
  }

  /// Массово сохраняет бюджеты, которым только что проставили `serverId`
  /// по ответу `/sync/` — см. [putTransactions].
  void putBudgets(List<Budget> budgets) {
    if (budgets.isEmpty) return;
    _budgetBox.putMany(budgets);
  }

  /// Возвращает лимиты бюджета, ещё не отправленные на сервер (`serverId == null`
  /// или `isModified == true`).
  /// Используется при синхронизации гостевых/локальных данных после входа/редактирования.
  List<Budget> getUnsyncedBudgets() {
    final query = _budgetBox
        .query(Budget_.serverId.isNull().or(Budget_.isModified.equals(true)))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Приводит локальные лимиты бюджета в соответствие с состоянием сервера —
  /// см. [reconcileTransactions], правила те же.
  int reconcileBudgets(List<Budget> remote) {
    return _store.runInTransaction(TxMode.write, () {
      final toPut = <Budget>[];

      for (final budget in remote) {
        final localId = _linkToExistingBudget(budget);
        if (localId != null) {
          final existing = _budgetBox.get(localId);
          if (existing != null && existing.isModified) {
            continue;
          }
        }
        toPut.add(budget);
      }
      _budgetBox.putMany(toPut);

      final remoteIds =
          remote.map((b) => b.serverId).whereType<String>().toSet();

      final query = _budgetBox
          .query(
              Budget_.serverId.notNull().and(Budget_.isModified.equals(false)))
          .build();
      final candidates = query.find();
      query.close();

      final stale = candidates
          .where((b) => !remoteIds.contains(b.serverId))
          .map((b) => b.localId)
          .toList();

      _budgetBox.removeMany(stale);
      return stale.length;
    });
  }

  /// Удаляет лимит бюджета по локальному ID. Возвращает `true`, если запись
  /// была найдена и удалена.
  bool deleteBudget(int id) {
    final removed = _budgetBox.remove(id);
    AppLogger.d('[LocalDbService] Removed budget $id: $removed');
    return removed;
  }

  /// Считает сумму расходов по конкретной категории за месяц и год с динамической
  /// конвертацией в текущую валюту аккаунта.
  double getSpentForCategory(int month, int year, String categoryName,
      [Currency? targetCurrency]) {
    final transactions = getTransactionsForPeriod(month, year);
    final currency = targetCurrency ?? CurrencyFormatter.currentCurrency;
    final exchange = CurrencyExchangeService.instance;

    double totalSpent = 0;
    for (final t in transactions) {
      if (t.dbCategory == categoryName && t.type == TransactionType.expense) {
        totalSpent += t.currency == currency
            ? t.amount
            : exchange.convert(t.amount, from: t.currency, to: currency);
      }
    }
    return totalSpent;
  }

  /// Закрепляет прежнюю базовую валюту за лимитами без своей валюты
  /// (созданы до появления валюты лимита и велись в базовой).
  ///
  /// Суммы лимитов при смене базовой валюты не пересчитываются: у каждого
  /// лимита своя валюта, как и на сервере. Синхронизированные лимиты
  /// помечаются изменёнными, чтобы сервер получил их валюту явно.
  void pinLegacyBudgetsCurrency(Currency previousBase) {
    try {
      final legacy =
          _budgetBox.getAll().where((b) => b.currencyCode == null).toList();
      if (legacy.isEmpty) return;

      for (final b in legacy) {
        b.currencyCode = previousBase.code;
        if (b.serverId != null) b.isModified = true;
      }
      _budgetBox.putMany(legacy);
      AppLogger.d('[LocalDbService] Pinned ${legacy.length} budgets to '
          '${previousBase.code}');
    } catch (e, s) {
      AppLogger.e('[LocalDbService] pinLegacyBudgetsCurrency error', e, s);
    }
  }

  Future<void> clearAllData() async {
    _transactionBox.removeAll();
    _budgetBox.removeAll();
  }
}
