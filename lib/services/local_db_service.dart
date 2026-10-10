import 'package:getbalanceai_mobile/models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../objectbox.g.dart';
import '../utils/app_logger.dart';

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
  static late final LocalDbService instance;

  late final Store _store;
  late final Box<Transaction> _transactionBox;
  late final Box<Budget> _budgetBox;

  LocalDbService._create(this._store) {
    _transactionBox = Box<Transaction>(_store);
    _budgetBox = Box<Budget>(_store);
  }

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

  /// Считает общие итоги (доход и расход) за выбранный месяц.
  /// Использует эффективные агрегатные функции ObjectBox.
  Map<String, double> getMonthTotals(int month, int year) {
    final startOfMonth = DateTime(year, month, 1).millisecondsSinceEpoch;
    final endOfMonth = DateTime(year, month + 1, 1)
        .subtract(const Duration(milliseconds: 1))
        .millisecondsSinceEpoch;

    final incomeQuery = _transactionBox
        .query(
          Transaction_.dateMilliseconds.between(startOfMonth, endOfMonth) &
              Transaction_.dbType.equals(TransactionType.income.name),
        )
        .build();

    final expenseQuery = _transactionBox
        .query(
          Transaction_.dateMilliseconds.between(startOfMonth, endOfMonth) &
              Transaction_.dbType.equals(TransactionType.expense.name),
        )
        .build();

    final income = incomeQuery.property(Transaction_.amount).sum();
    final expense = expenseQuery.property(Transaction_.amount).sum();

    incomeQuery.close();
    expenseQuery.close();

    return {'income': income, 'expense': expense};
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

  /// Добавляет новую транзакцию (доход или расход) и возвращает её локальный ID.
  int addTransaction(Transaction transaction) {
    return _transactionBox.put(transaction);
  }

  /// Сохраняет транзакцию: если `localId` уже существует — обновляет запись,
  /// иначе создаёт новую (поведение ObjectBox `Box.put`).
  void saveTransaction(Transaction transaction) {
    _linkToExistingTransaction(transaction);
    final id = _transactionBox.put(transaction);
    AppLogger.d('[LocalDbService] Saved transaction localId: $id');
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
  int reconcileTransactions(List<Transaction> remote) {
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

  /// Считает сумму расходов по конкретной категории за месяц и год.
  double getSpentForCategory(int month, int year, String categoryName) {
    final startOfMonth = DateTime(year, month, 1);
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endOfMonth = DateTime(nextYear, nextMonth, 1)
        .subtract(const Duration(milliseconds: 1));

    final query = _transactionBox
        .query(Transaction_.dbCategory.equals(categoryName) &
            Transaction_.dbType.equals(TransactionType.expense.name) &
            Transaction_.dateMilliseconds.between(
                startOfMonth.millisecondsSinceEpoch,
                endOfMonth.millisecondsSinceEpoch))
        .build();

    final totalSpent = query.property(Transaction_.amount).sum();
    query.close();
    return totalSpent;
  }

  Future<void> clearAllData() async {
    _transactionBox.removeAll();
    _budgetBox.removeAll();
  }
}
