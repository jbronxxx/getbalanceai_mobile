import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';

/// Очередь удалений, которые ещё не доехали до сервера («надгробия»).
///
/// Нужна из-за асимметрии синхронизации. Создание и изменение записи видно
/// по самой записи, а вот удаление не оставляет в локальной базе никакого
/// следа: строки просто нет. Поэтому загрузка с сервера не может отличить
/// «эту запись удалили на устройстве» от «эту запись на устройстве ещё не
/// видели» — и вернула бы удалённую транзакцию назад.
///
/// Сюда попадают `serverId` записей, удалённых пока приложение было без
/// сети или без авторизации (гостевой режим после выхода из аккаунта), и на
/// время онлайн-удаления. Очередь уходит на сервер в выгрузке
/// [SyncService] — в `deleted_transaction_ids`/`deleted_budget_ids`/
/// `deleted_recurring_payment_ids` запроса `/sync/`, без отдельного DELETE
/// на каждую запись.
///
/// Хранится файлом в каталоге документов приложения, а не в локальной БД:
/// для новой ObjectBox-сущности потребовалась бы перегенерация
/// `objectbox.g.dart`. Файл переживает перезапуск приложения и выход из
/// аккаунта, но удаляется вместе с приложением — это правильно: после
/// переустановки сервер остаётся единственным источником данных, и
/// проигрывать старые удаления уже нечему.
class PendingDeletionsStore {
  static PendingDeletionsStore? _instance;
  static PendingDeletionsStore get instance =>
      _instance ??= PendingDeletionsStore._(null, {}, {}, {});
  static set instance(PendingDeletionsStore value) => _instance = value;

  final File? _file;
  final Set<String> _transactionIds;
  final Set<String> _budgetIds;
  final Set<String> _recurringIds;

  PendingDeletionsStore._(
    this._file,
    this._transactionIds,
    this._budgetIds,
    this._recurringIds,
  );

  /// Читает очередь с диска и инициализирует [instance]. Вызывается один раз
  /// при старте приложения. Повреждённый или нечитаемый файл не считается
  /// ошибкой: очередь просто начинается пустой, иначе приложение не
  /// запустилось бы из-за вспомогательных данных.
  static Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, 'pending_deletions.json'));
    final transactionIds = <String>{};
    final budgetIds = <String>{};
    final recurringIds = <String>{};

    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());

        if (decoded is Map) {
          final txs = decoded['transactions'];
          if (txs is List) transactionIds.addAll(txs.whereType<String>());

          final bgts = decoded['budgets'];
          if (bgts is List) budgetIds.addAll(bgts.whereType<String>());

          final recurring = decoded['recurring_payments'];
          if (recurring is List) {
            recurringIds.addAll(recurring.whereType<String>());
          }
        } else if (decoded is List) {
          // Миграция со старого формата, где был только список ID транзакций.
          transactionIds.addAll(decoded.whereType<String>());
        }
      }
    } catch (e) {
      AppLogger.w('Не удалось прочитать очередь удалений: $e');
    }

    instance =
        PendingDeletionsStore._(file, transactionIds, budgetIds, recurringIds);
  }

  /// `serverId` транзакций, удаление которых ещё нужно повторить на сервере.
  Set<String> get transactionIds => Set.unmodifiable(_transactionIds);

  /// `serverId` бюджетов, удаление которых ещё нужно повторить на сервере.
  Set<String> get budgetIds => Set.unmodifiable(_budgetIds);

  /// `uid` регулярных платежей, удаление которых ещё нужно повторить.
  Set<String> get recurringPaymentIds => Set.unmodifiable(_recurringIds);

  bool get isEmpty =>
      _transactionIds.isEmpty && _budgetIds.isEmpty && _recurringIds.isEmpty;

  /// Сколько удалений ждёт отправки на сервер.
  int get count =>
      _transactionIds.length + _budgetIds.length + _recurringIds.length;

  /// Растёт при каждом изменении очереди — по нему Профиль пересчитывает
  /// число неотправленных изменений.
  static final ValueNotifier<int> changed = ValueNotifier(0);

  Future<void> addTransaction(String serverId) async {
    if (_transactionIds.add(serverId)) await _flush();
  }

  Future<void> addBudget(String serverId) async {
    if (_budgetIds.add(serverId)) await _flush();
  }

  Future<void> addRecurringPayment(String uid) async {
    if (_recurringIds.add(uid)) await _flush();
  }

  /// Убирает из очереди удаления, доехавшие до сервера.
  Future<void> removeTransactions(Iterable<String> serverIds) async {
    final sizeBefore = _transactionIds.length;
    _transactionIds.removeAll(serverIds.toSet());

    if (_transactionIds.length != sizeBefore) await _flush();
  }

  /// Убирает из очереди удаления бюджетов, доехавшие до сервера.
  Future<void> removeBudgets(Iterable<String> serverIds) async {
    final sizeBefore = _budgetIds.length;
    _budgetIds.removeAll(serverIds.toSet());

    if (_budgetIds.length != sizeBefore) await _flush();
  }

  /// Убирает из очереди удаления регулярных платежей, доехавшие до сервера.
  Future<void> removeRecurringPayments(Iterable<String> uids) async {
    final sizeBefore = _recurringIds.length;
    _recurringIds.removeAll(uids.toSet());

    if (_recurringIds.length != sizeBefore) await _flush();
  }

  Future<void> _flush() async {
    changed.value++;
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'transactions': _transactionIds.toList(),
        'budgets': _budgetIds.toList(),
        'recurring_payments': _recurringIds.toList(),
      }));
    } catch (e) {
      // Запись не удалась — очередь останется только в памяти и будет
      // потеряна при перезапуске. Это лучше, чем упасть в момент удаления
      // транзакции, но знать об этом в логах полезно.
      AppLogger.w('Не удалось сохранить очередь удалений: $e');
    }
  }

  /// Полностью очищает очередь удалений.
  Future<void> clear() async {
    _transactionIds.clear();
    _budgetIds.clear();
    _recurringIds.clear();
    await _flush();
  }
}
