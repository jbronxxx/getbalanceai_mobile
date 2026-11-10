import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show listEquals, mapEquals, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../config/secure_storage_config.dart';
import '../config/environment.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import '../utils/language_manager.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';

/// Коды ошибок синхронизации.
enum SyncErrorCode {
  unauthorized,
  syncFailed,
  loadFailed,
}

/// Исключение процесса синхронизации с поддержкой локализации.
class SyncException implements Exception {
  final SyncErrorCode code;
  final int? statusCode;
  final dynamic cause;

  const SyncException(this.code, {this.statusCode, this.cause});

  String getLocalizedMessage([AppLocalizations? l10n]) {
    final l = l10n ?? LanguageManager.l10n;
    switch (code) {
      case SyncErrorCode.unauthorized:
        return l.sync_login_required;
      case SyncErrorCode.syncFailed:
        return statusCode != null
            ? '${l.sync_error}: $statusCode'
            : l.sync_error;
      case SyncErrorCode.loadFailed:
        return statusCode != null
            ? '${l.sync_error}: $statusCode'
            : l.sync_error;
    }
  }

  @override
  String toString() => getLocalizedMessage();
}

/// Изменения операций с сервера (`GET /sync/changes`).
class _TransactionChanges {
  final List<Transaction> transactions;
  final List<String> deletedServerIds;

  /// Получены все страницы: только тогда [serverTime] можно сохранить как
  /// отметку следующей синхронизации.
  final bool isComplete;

  /// Время сервера на момент первой страницы.
  final DateTime serverTime;

  const _TransactionChanges({
    required this.transactions,
    required this.deletedServerIds,
    required this.isComplete,
    required this.serverTime,
  });
}

/// Ответ GET списка с ETag: [items] `null` — список не изменился (304).
class _RemoteListResult {
  final List<Map<String, dynamic>>? items;
  final String? newEtag;

  const _RemoteListResult({this.items, this.newEtag});
}

/// Сервис синхронизации локальных данных с сервером.
///
/// Выгрузка, загрузка и полная синхронизация идут через одну очередь
/// ([_enqueue]): ответ сервера применяется к базе только после того, как
/// закончилась предыдущая операция, и не перетирает чужие изменения.
class SyncService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Options Function([String? token]) _authOptions;
  final String? Function() _tokenProvider;
  final String? Function()? _userIdProvider;

  static const _uuid = Uuid();

  /// Сколько записей каждого вида уходит в один запрос `/sync/`.
  ///
  /// Бэкенд принимает не больше 500 элементов в каждом списке батча и
  /// отвечает 422 на весь запрос, если их больше. 200 оставляет запас и
  /// держит тело запроса небольшим на медленной сети.
  static const syncBatchSize = 200;

  /// Размер страницы `GET /sync/changes` (максимум сервера).
  static const _changesPageSize = 500;

  String? _budgetsEtag;
  String? _recurringEtag;

  /// `server_time` прошлой полной загрузки изменений: с него сервер отдаёт
  /// только изменённые и удалённые операции. `null` — загрузить всё.
  DateTime? _changesSince;

  /// Хвост очереди синхронизации: каждая новая операция ждёт предыдущую.
  Future<void> _queueTail = Future.value();

  SyncService({
    required Dio dio,
    required Options Function([String? token]) authOptions,
    required String? Function() tokenProvider,
    String? Function()? userIdProvider,
    FlutterSecureStorage storage = appSecureStorage,
  })  : _dio = dio,
        _authOptions = authOptions,
        _tokenProvider = tokenProvider,
        _userIdProvider = userIdProvider,
        _storage = storage;

  String get _budgetsEtagKey => _etagKey('budgets');
  String get _recurringEtagKey => _etagKey('recurring_payments');
  String get _changesSinceKey => _etagKey('transactions_since');

  String _etagKey(String entity, [String? userId]) {
    final owner = userId ?? _userIdProvider?.call() ?? 'anon';
    final env = EnvironmentConfig.current.name;
    return '${entity}_etag_${owner}_$env';
  }

  /// Отметка прошлой синхронизации операций (для тестов).
  @visibleForTesting
  DateTime? get changesSince => _changesSince;

  /// userId аккаунта, которому принадлежат операции и лимиты на устройстве.
  /// `null` — владельца нет: гостевые данные или база очищена при выходе.
  static const _localDataOwnerKey = 'local_data_owner';
  String? _localDataOwner;

  /// [stored] — содержимое хранилища, уже прочитанное одним `readAll()`
  /// (см. `AuthApiService.init`); без него хранилище читается здесь.
  Future<void> init([Map<String, String>? stored]) async {
    stored ??= await _storage.readAll();
    _changesSince = DateTime.tryParse(stored[_changesSinceKey] ?? '');
    _budgetsEtag = stored[_budgetsEtagKey];
    _recurringEtag = stored[_recurringEtagKey];
    _localDataOwner = stored[_localDataOwnerKey];
  }

  /// Сбрасывает ETag лимитов и отметку прошлой синхронизации операций
  /// пользователя [userId] (по умолчанию — текущего): следующая загрузка
  /// будет полной. Ключи привязаны к userId, поэтому при выходе его нужно
  /// передать явно или вызвать до очистки сессии.
  Future<void> clearEtags({String? userId}) async {
    _changesSince = null;
    _budgetsEtag = null;
    _recurringEtag = null;
    try {
      await _storage.delete(key: _etagKey('transactions_since', userId));
      await _storage.delete(key: _etagKey('budgets', userId));
      await _storage.delete(key: _etagKey('recurring_payments', userId));
      // Прежние ключи: ETag списка операций до перехода на /sync/changes
      await _storage.delete(key: _etagKey('transactions', userId));
      await _storage.delete(key: 'transactions_etag');
      await _storage.delete(key: 'budgets_etag');
    } catch (_) {}
  }

  /// Стирает локальные данные вышедшего пользователя [userId]: операции,
  /// лимиты, очередь удалений, ETag и отметку владельца.
  ///
  /// Выполняется в очереди синхронизации: синк, начатый до выхода, сначала
  /// завершится, и его ответ не вернёт записи в уже очищенную базу. Сессию
  /// нужно очистить до вызова — тогда задачи, поставленные позже, упадут
  /// с [SyncErrorCode.unauthorized], а не загрузят данные заново.
  Future<void> clearLocalData({String? userId}) =>
      _enqueue(() => _clearLocalData(userId));

  /// Закрепляет данные на устройстве за [userId] (вход или старт приложения).
  ///
  /// Если они принадлежат другому аккаунту — сессия того истекла без выхода,
  /// и база не очищалась, — они стираются: иначе невыгруженные записи
  /// прошлого пользователя ушли бы в аккаунт [userId]. Данные без владельца
  /// (гостевые) переносятся в аккаунт.
  Future<void> claimLocalData(String userId) => _enqueue(() async {
        final owner = _localDataOwner;
        if (owner == userId) return;
        if (owner != null) {
          AppLogger.i('[SyncService] Local data belongs to another account, '
              'clearing');
          await _clearLocalData(owner);
        }
        _localDataOwner = userId;
        await _storage.write(key: _localDataOwnerKey, value: userId);
      });

  Future<void> _clearLocalData(String? userId) async {
    await clearEtags(userId: userId);
    if (LocalDbService.isInitialized) {
      await LocalDbService.instance.clearAllData();
    }
    await PendingDeletionsStore.instance.clear();
    _localDataOwner = null;
    await _storage.delete(key: _localDataOwnerKey);
  }

  /// Ставит [task] в очередь синхронизации: он начнётся только после
  /// завершения (успешного или нет) всех ранее поставленных задач.
  ///
  /// Без очереди push из шторки, pull-to-refresh и push перед инсайтами шли
  /// параллельно, и ответ одного запроса записывал в базу объекты,
  /// прочитанные до другого, — правка пользователя терялась.
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final run = _queueTail.then((_) => task());
    _queueTail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Синк только для вошедшего пользователя. Токен в запросы подставляет
  /// интерцептор [ApiService] — актуальный на момент запроса: пока задача
  /// ждала в очереди или листала страницы, токен мог обновиться.
  void _requireSession() {
    if (_tokenProvider() == null) {
      throw const SyncException(SyncErrorCode.unauthorized);
    }
  }

  /// Выгружает локальные транзакции и бюджеты на сервер.
  Future<Map<String, dynamic>> syncLocalDataToBackend() async {
    _requireSession();
    return _enqueue(() {
      _requireSession();
      return _push();
    });
  }

  /// Загружает транзакции и бюджеты пользователя с сервера в локальную базу.
  Future<Map<String, dynamic>> syncBackendDataToLocal({
    int maxPages = 100,
  }) async {
    _requireSession();
    return _enqueue(() {
      _requireSession();
      return _pull(maxPages);
    });
  }

  /// Полная двусторонняя синхронизация — одна задача в очереди: между
  /// выгрузкой и загрузкой не вклинится другой запрос.
  ///
  /// Удаления из очереди уходят в той же выгрузке (`deleted_*_ids` в
  /// `/sync/`), без отдельного DELETE на каждую запись.
  Future<Map<String, dynamic>> syncAll({
    int maxPages = 100,
  }) async {
    _requireSession();
    return _enqueue(() async {
      _requireSession();
      final pushed = await _push();
      final pulled = await _pull(maxPages);

      return {'pushed': pushed, 'pulled': pulled};
    });
  }

  Future<Map<String, dynamic>> _push() async {
    try {
      final localTransactions =
          LocalDbService.instance.getUnsyncedTransactions();
      _assignClientTransactionIds(localTransactions);
      final localBudgets = LocalDbService.instance.getUnsyncedBudgets();
      final localRecurring =
          LocalDbService.instance.getUnsyncedRecurringPayments();
      final pendingBudgets = PendingDeletionsStore.instance.budgetIds.toList();
      final pendingTransactions =
          PendingDeletionsStore.instance.transactionIds.toList();
      final pendingRecurring =
          PendingDeletionsStore.instance.recurringPaymentIds.toList();

      if (localTransactions.isEmpty &&
          localBudgets.isEmpty &&
          localRecurring.isEmpty &&
          pendingBudgets.isEmpty &&
          pendingTransactions.isEmpty &&
          pendingRecurring.isEmpty) {
        return {'message': 'Нет данных для синхронизации'};
      }

      final batches = [
        localTransactions.length,
        localBudgets.length,
        localRecurring.length,
        pendingBudgets.length,
        pendingTransactions.length,
        pendingRecurring.length,
      ].map((n) => (n / syncBatchSize).ceil()).reduce(math.max);

      var syncedTransactions = 0;
      var syncedBudgets = 0;
      var syncedRecurring = 0;
      final rejected = <Map<String, dynamic>>[];

      // Каждый батч фиксируется в базе сразу после ответа: если упадёт
      // следующий, уже принятые сервером записи не уйдут повторно.
      for (var i = 0; i < batches; i++) {
        final sentTransactions = {
          for (final t in _batch(localTransactions, i)) t.localId: t.toJson(),
        };
        final sentBudgets = {
          for (final b in _batch(localBudgets, i)) b.localId: b.toJson(),
        };
        final sentRecurring = {
          for (final p in _batch(localRecurring, i)) p.localId: p.toJson(),
        };
        final deletedBudgets = _batch(pendingBudgets, i);
        final deletedTransactions = _batch(pendingTransactions, i);
        final deletedRecurring = _batch(pendingRecurring, i);

        // Удаление лимитов — только через `deleted_budget_ids`: элемент
        // `budgets` без категории и периода сервер отклоняет 422 вместе со
        // всем батчем.
        final payload = SyncModel(
          transactions: sentTransactions.values.toList(),
          budgets: sentBudgets.values.toList(),
          recurringPayments: sentRecurring.values.toList(),
          deletedBudgetIds: deletedBudgets,
          deletedTransactionIds: deletedTransactions,
          deletedRecurringPaymentIds: deletedRecurring,
        );

        final response = await _dio.post(
          ApiConfig.sync,
          data: payload.toJson(),
          options: _authOptions(),
        );

        final data = _syncResponseData(response.data);
        final batchRejected = _asJsonList(data['rejected']);

        syncedTransactions += _confirmTransactions(
            sentTransactions, data['synced_transactions'], batchRejected);
        syncedBudgets +=
            _confirmBudgets(sentBudgets, data['synced_budgets'], batchRejected);
        // Сервер без регулярных платежей поля не вернёт — они останутся
        // в очереди до обновления сервера.
        if (data['synced_recurring_payments'] is List) {
          syncedRecurring += _confirmRecurringPayments(
              sentRecurring, data['synced_recurring_payments'], batchRejected);
          if (deletedRecurring.isNotEmpty) {
            await PendingDeletionsStore.instance
                .removeRecurringPayments(deletedRecurring);
          }
        }
        rejected.addAll(batchRejected);

        if (deletedBudgets.isNotEmpty) {
          await PendingDeletionsStore.instance.removeBudgets(deletedBudgets);
        }
        if (deletedTransactions.isNotEmpty) {
          await PendingDeletionsStore.instance
              .removeTransactions(deletedTransactions);
        }
      }

      if (rejected.isNotEmpty) {
        AppLogger.w('[SyncService] Rejected by server: ${rejected.length} '
            '(${rejected.map(_rejectCode).toSet().join(', ')})');
      }
      AppLogger.i('[SyncService] Sync local -> backend success: '
          'T($syncedTransactions/${localTransactions.length}), '
          'B($syncedBudgets/${localBudgets.length}), '
          'R($syncedRecurring/${localRecurring.length}), batches: $batches');
      return {
        'synced_transactions': syncedTransactions,
        'synced_budgets': syncedBudgets,
        'synced_recurring_payments': syncedRecurring,
        'rejected': rejected,
      };
    } on DioException catch (e) {
      AppLogger.e('[SyncService] Sync error: ${e.response?.statusCode}', e);
      throw SyncException(SyncErrorCode.syncFailed,
          statusCode: e.response?.statusCode, cause: e);
    } catch (e) {
      AppLogger.e('[SyncService] Sync unexpected error', e);
      rethrow;
    }
  }

  List<T> _batch<T>(List<T> items, int index) {
    final start = index * syncBatchSize;
    if (start >= items.length) return <T>[];
    return items.sublist(start, math.min(start + syncBatchSize, items.length));
  }

  /// Тело ответа `/sync/`. Ответ не той формы — ошибка, а не «сервер ничего
  /// не принял»: иначе очередь удалений очистилась бы без подтверждения.
  Map<String, dynamic> _syncResponseData(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is Map &&
        data['synced_transactions'] is List &&
        data['synced_budgets'] is List) {
      return data.cast<String, dynamic>();
    }
    throw const SyncException(
      SyncErrorCode.syncFailed,
      cause: FormatException('Unexpected /sync/ response shape'),
    );
  }

  Future<Map<String, dynamic>> _pull(int maxPages) async {
    try {
      final db = LocalDbService.instance;
      // Без отметки или с пустой базой — полная загрузка со сверкой: записи,
      // которых нет на сервере, удаляются локально.
      final since = db.hasTransactions ? _changesSince : null;
      final changes = await _fetchTransactionChanges(
        since: since,
        maxPages: maxPages,
      );
      final remoteBudgetsResult = await _fetchRemoteList(
        path: ApiConfig.budgets,
        etagKey: _budgetsEtagKey,
        etag: _budgetsEtag,
        hasLocal: db.hasBudgets,
        entity: 'budgets',
      );
      final remoteBudgets = remoteBudgetsResult.items
          ?.map(Budget.fromJson)
          .where((b) => b.isValidPeriod)
          .toList();
      final remoteRecurringResult = await _fetchRecurringPayments();

      // Отметка и ETag сохраняются только после того, как данные легли в
      // базу: если загрузка или сверка оборвётся раньше, следующий синк
      // запросит те же изменения снова.
      final int removedTransactions;
      if (since != null) {
        removedTransactions = db.applyRemoteTransactionChanges(
          changes.transactions,
          changes.deletedServerIds,
        );
      } else if (changes.isComplete) {
        removedTransactions = db.reconcileTransactions(changes.transactions);
      } else {
        db.upsertRemoteTransactions(changes.transactions);
        removedTransactions = 0;
      }
      if (changes.isComplete) {
        await _saveChangesSince(changes.serverTime);
      }

      int removedBudgets = 0;
      int budgetsLength = 0;
      if (remoteBudgets != null) {
        removedBudgets = db.reconcileBudgets(remoteBudgets);
        budgetsLength = remoteBudgets.length;
        await _saveEtag(_budgetsEtagKey, remoteBudgetsResult.newEtag);
        _budgetsEtag = remoteBudgetsResult.newEtag ?? _budgetsEtag;
      } else {
        AppLogger.i(
            '[SyncService] Budgets not modified (304). Skipping reconciliation.');
        budgetsLength = db.budgetsCount;
      }

      var removedRecurring = 0;
      final remoteRecurring = remoteRecurringResult?.items;
      if (remoteRecurring != null) {
        removedRecurring = db.reconcileRecurringPayments(remoteRecurring
            .map(RecurringPayment.fromJson)
            .where((p) => p.isValid)
            .toList());
        await _saveEtag(_recurringEtagKey, remoteRecurringResult!.newEtag);
        _recurringEtag = remoteRecurringResult.newEtag ?? _recurringEtag;
      }

      final transactionsChanged = changes.transactions.isNotEmpty ||
          changes.deletedServerIds.isNotEmpty ||
          removedTransactions > 0;
      AppLogger.i('[SyncService] Sync backend -> local '
          '(${since == null ? 'full' : 'changes'}): '
          'T(${changes.transactions.length}, '
          'deleted ${changes.deletedServerIds.length}), B($budgetsLength); '
          'Removed: T($removedTransactions), B($removedBudgets), '
          'R($removedRecurring)');

      // Один сигнал на загрузку, и только если с сервера пришли изменения:
      // экраны перечитают данные, но не на каждой записи в базу.
      if (transactionsChanged || remoteBudgets != null) {
        LocalDbService.transactionsChanged.value++;
      }

      return {
        'transactions': changes.transactions.length,
        'deleted_transactions': changes.deletedServerIds.length,
        'budgets': budgetsLength,
        'removed_transactions': removedTransactions,
        'removed_budgets': removedBudgets,
        'removed_recurring_payments': removedRecurring,
      };
    } on DioException catch (e) {
      AppLogger.e('[SyncService] Load error: ${e.response?.statusCode}', e);
      throw SyncException(SyncErrorCode.loadFailed,
          statusCode: e.response?.statusCode, cause: e);
    } catch (e) {
      AppLogger.e('[SyncService] Load unexpected error', e);
      rethrow;
    }
  }

  Future<void> _saveChangesSince(DateTime serverTime) async {
    _changesSince = serverTime;
    await _storage.write(
      key: _changesSinceKey,
      value: serverTime.toUtc().toIso8601String(),
    );
  }

  Future<void> _saveEtag(String key, String? etag) async {
    if (etag == null) return;
    await _storage.write(key: key, value: etag);
  }

  /// Забирает изменения операций с [since] (без него — все операции)
  /// страницами по [_changesPageSize], не больше [maxPages] страниц.
  ///
  /// Ответ не той формы — ошибка: пустой список при сверке удалил бы все
  /// выгруженные операции.
  Future<_TransactionChanges> _fetchTransactionChanges({
    required DateTime? since,
    required int maxPages,
  }) async {
    final transactions = <Transaction>[];
    final deleted = <String>[];
    DateTime? serverTime;
    String? cursor;
    var hasMore = true;
    var page = 0;

    while (hasMore && page < maxPages) {
      page++;
      final response = await _dio.get(
        ApiConfig.syncChanges,
        queryParameters: {
          'limit': _changesPageSize,
          if (since != null) 'since': since.toUtc().toIso8601String(),
          if (cursor != null) 'cursor': cursor,
        },
        options: _authOptions(),
      );

      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map ||
          data['transactions'] is! List ||
          data['deleted_transaction_ids'] is! List) {
        throw const SyncException(
          SyncErrorCode.loadFailed,
          cause: FormatException('Unexpected /sync/changes response shape'),
        );
      }
      serverTime ??= DateTime.tryParse('${data['server_time']}');
      if (serverTime == null) {
        throw const SyncException(
          SyncErrorCode.loadFailed,
          cause: FormatException('/sync/changes without server_time'),
        );
      }

      transactions
          .addAll(_asJsonList(data['transactions']).map(Transaction.fromJson));
      deleted.addAll(
          (data['deleted_transaction_ids'] as List).whereType<String>());

      cursor = data['next_cursor'] as String?;
      hasMore = data['has_more'] == true && cursor != null;
    }

    if (hasMore) {
      AppLogger.w(
          '[SyncService] Transaction changes limit ($maxPages pages) reached.');
    }
    return _TransactionChanges(
      transactions: transactions,
      deletedServerIds: deleted,
      isComplete: !hasMore,
      serverTime: serverTime!,
    );
  }

  /// GET полного списка с ETag: [etag] уходит в `If-None-Match`, только
  /// если локально уже есть данные (иначе 304 оставил бы базу пустой).
  Future<_RemoteListResult> _fetchRemoteList({
    required String path,
    required String etagKey,
    required String? etag,
    required bool hasLocal,
    required String entity,
  }) async {
    final options = _authOptions();
    options.validateStatus = (status) =>
        status != null && ((status >= 200 && status < 300) || status == 304);

    if (hasLocal) {
      etag ??= await _storage.read(key: etagKey);
      if (etag != null) options.headers?['If-None-Match'] = etag;
    }

    final response = await _dio.get(path, options: options);
    if (response.statusCode == 304) return const _RemoteListResult();

    final data = response.data is Map ? response.data['data'] : null;
    return _RemoteListResult(
      items: _requireJsonList(data, entity),
      newEtag: response.headers.value('etag'),
    );
  }

  /// Регулярные платежи с сервера; `null` — сервер ещё без регулярных
  /// платежей (404, приложение обновили раньше сервера): загрузка остального
  /// не должна из-за этого падать.
  Future<_RemoteListResult?> _fetchRecurringPayments() async {
    try {
      return await _fetchRemoteList(
        path: ApiConfig.recurringPayments,
        etagKey: _recurringEtagKey,
        etag: _recurringEtag,
        hasLocal: LocalDbService.instance.hasRecurringPayments,
        entity: 'recurring_payments',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        AppLogger.w('[SyncService] Server without recurring payments (404)');
        return null;
      }
      rethrow;
    }
  }

  /// Присваивает UUID новым транзакциям до отправки и сохраняет его локально.
  ///
  /// Сервер делает upsert по клиентскому `id`: если ответ на `/sync/` потерян
  /// уже после записи на сервере, повтор того же батча обновит те же строки,
  /// а не создаст дубли. `isModified = true` держит запись в очереди
  /// невыгруженных, пока сервер её не подтвердит.
  void _assignClientTransactionIds(List<Transaction> transactions) {
    final fresh = transactions.where((t) => t.serverId == null).toList();
    if (fresh.isEmpty) return;
    for (final t in fresh) {
      t.serverId = _uuid.v4();
      t.isModified = true;
    }
    LocalDbService.instance.putTransactions(fresh);
  }

  /// Код причины отказа по ID записи: `code` из `rejected`, а если сервер
  /// его не прислал — [Transaction.unknownRejectCode] или [_idConflictCode],
  /// распознанный по тексту `reason`.
  Map<String, String> _rejectedCodes(List<Map<String, dynamic>> rejected) {
    return {
      for (final json in rejected)
        if (json['id'] is String) json['id'] as String: _rejectCode(json),
    };
  }

  /// ID записи принадлежит чужой записи на сервере: повтор с тем же ID
  /// отклонялся бы вечно, поэтому запись перевыпускается.
  static const _idConflictCode = 'ID_CONFLICT';

  static String _rejectCode(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is String && code.isNotEmpty) return code;
    final reason = json['reason'];
    if (reason is String && reason.contains('конфликт идентификатора')) {
      return _idConflictCode;
    }
    return Transaction.unknownRejectCode;
  }

  /// Фиксирует в базе ответ `/sync/` для отправленных транзакций.
  ///
  /// [sent] — снимок тел запроса по `localId`. Строки перечитываются из
  /// базы, потому что пока шёл запрос, пользователь мог их изменить или
  /// удалить:
  /// - синхронизированной считается только запись, чей `id` вернулся в
  ///   `synced_transactions`, и только если её содержимое не менялось после
  ///   отправки — иначе правка остаётся в очереди невыгруженных;
  /// - удалённая за время запроса строка не возвращается в базу;
  /// - запись, отклонённая из-за конфликта ID, получает новый UUID и уйдёт
  ///   при следующей выгрузке; прочие отказы остаются в очереди с кодом
  ///   причины в [Transaction.syncRejectCode], если запись не меняли после
  ///   отправки.
  ///
  /// Возвращает число подтверждённых записей.
  int _confirmTransactions(
    Map<int, Map<String, dynamic>> sent,
    dynamic synced,
    List<Map<String, dynamic>> rejected,
  ) {
    if (sent.isEmpty) return 0;
    final confirmedIds = _asJsonList(synced)
        .map((json) => json['id'])
        .whereType<String>()
        .toSet();
    final rejectedCodes = _rejectedCodes(rejected);

    final localIds = sent.keys.toList();
    final stored = LocalDbService.instance.getTransactionsByLocalIds(localIds);
    final toPut = <Transaction>[];
    var confirmed = 0;

    for (var i = 0; i < localIds.length; i++) {
      final row = stored[i];
      final snapshot = sent[localIds[i]]!;
      final sentId = snapshot['id'];
      if (row == null || sentId is! String || row.serverId != sentId) continue;

      final unchanged = mapEquals(row.toJson(), snapshot);
      if (confirmedIds.contains(sentId)) {
        confirmed++;
        if ((row.isModified && unchanged) || row.syncRejectCode != null) {
          if (unchanged) row.isModified = false;
          row.syncRejectCode = null;
          toPut.add(row);
        }
      } else if (rejectedCodes[sentId] == _idConflictCode) {
        row
          ..serverId = _uuid.v4()
          ..isModified = true
          ..syncRejectCode = null;
        toPut.add(row);
      } else if (rejectedCodes[sentId] case final code?
          when unchanged && row.syncRejectCode != code) {
        row.syncRejectCode = code;
        toPut.add(row);
      }
    }

    LocalDbService.instance.putTransactions(toPut);
    AppLogger.d('[SyncService] Confirmed transactions: '
        '$confirmed/${sent.length}');
    return confirmed;
  }

  /// То же, что [_confirmTransactions], для лимитов.
  ///
  /// Сервер делает upsert лимита по ключу «категория + месяц + год» и может
  /// вернуть ID уже существующей у него записи, а не отправленный. Поэтому
  /// ответ сопоставляется сначала по ID, затем по этому ключу (он уникален
  /// на сервере), но не по позиции в списке.
  int _confirmBudgets(
    Map<int, Map<String, dynamic>> sent,
    dynamic synced,
    List<Map<String, dynamic>> rejected,
  ) {
    if (sent.isEmpty) return 0;
    final byId = <String, Map<String, dynamic>>{};
    final byKey = <String, Map<String, dynamic>>{};
    for (final json in _asJsonList(synced)) {
      final id = json['id'];
      if (id is String) byId[id] = json;
      byKey[_budgetKey(json)] = json;
    }
    final rejectedCodes = _rejectedCodes(rejected);

    final localIds = sent.keys.toList();
    final stored = LocalDbService.instance.getBudgetsByLocalIds(localIds);
    final toPut = <Budget>[];
    var confirmed = 0;

    for (var i = 0; i < localIds.length; i++) {
      final row = stored[i];
      final snapshot = sent[localIds[i]]!;
      final sentId = snapshot['id'] as String?;
      if (row == null || row.serverId != sentId) continue;

      final match = (sentId != null ? byId[sentId] : null) ??
          (rejectedCodes.containsKey(sentId)
              ? null
              : byKey[_budgetKey(snapshot)]);
      final confirmedId = match?['id'];

      if (confirmedId is String) {
        confirmed++;
        final unchanged =
            mapEquals(_withoutId(row.toJson()), _withoutId(snapshot));
        if (row.serverId != confirmedId || (row.isModified && unchanged)) {
          row.serverId = confirmedId;
          if (unchanged) row.isModified = false;
          toPut.add(row);
        }
      } else if (rejectedCodes[sentId] == _idConflictCode) {
        // Без ID сервер найдёт или создаст лимит по ключу.
        row
          ..serverId = null
          ..isModified = true;
        toPut.add(row);
      }
    }

    LocalDbService.instance.putBudgets(toPut);
    AppLogger.d('[SyncService] Confirmed budgets: $confirmed/${sent.length}');
    return confirmed;
  }

  /// То же, что [_confirmTransactions], для регулярных платежей: ID создаёт
  /// устройство и сервер его не меняет; при конфликте ID платёж получает
  /// новый `uid` и уйдёт снова.
  int _confirmRecurringPayments(
    Map<int, Map<String, dynamic>> sent,
    dynamic synced,
    List<Map<String, dynamic>> rejected,
  ) {
    if (sent.isEmpty) return 0;
    final confirmedIds = _asJsonList(synced)
        .map((json) => json['id'])
        .whereType<String>()
        .toSet();
    final rejectedCodes = _rejectedCodes(rejected);

    final localIds = sent.keys.toList();
    final stored =
        LocalDbService.instance.getRecurringPaymentsByLocalIds(localIds);
    final toPut = <RecurringPayment>[];
    var confirmed = 0;

    for (var i = 0; i < localIds.length; i++) {
      final row = stored[i];
      final snapshot = sent[localIds[i]]!;
      if (row == null || row.uid != snapshot['id']) continue;

      if (confirmedIds.contains(row.uid)) {
        confirmed++;
        row.isOnServer = true;
        if (_sameRecurringPayment(row.toJson(), snapshot)) {
          row.isModified = false;
        }
        toPut.add(row);
      } else if (rejectedCodes[row.uid] == _idConflictCode) {
        row
          ..uid = _uuid.v4()
          ..isModified = true
          ..isOnServer = false;
        toPut.add(row);
      }
    }

    LocalDbService.instance.putRecurringPayments(toPut);
    return confirmed;
  }

  /// Тело платежа не менялось после отправки (список пропусков — по
  /// содержимому: `mapEquals` сравнивает списки по ссылке).
  static bool _sameRecurringPayment(
      Map<String, dynamic> current, Map<String, dynamic> sent) {
    const skipped = 'skipped_periods';
    return mapEquals(
            Map.of(current)..remove(skipped), Map.of(sent)..remove(skipped)) &&
        listEquals(current[skipped] as List?, sent[skipped] as List?);
  }

  static String _budgetKey(Map<String, dynamic> json) =>
      '${json['category']}|${json['month']}|${json['year']}';

  static Map<String, dynamic> _withoutId(Map<String, dynamic> json) =>
      Map.of(json)..remove('id');

  /// Список записей из ответа GET. Ответ не той формы — ошибка: принять его
  /// за пустой полный список значило бы удалить при сверке все
  /// синхронизированные записи.
  List<Map<String, dynamic>> _requireJsonList(dynamic value, String entity) {
    if (value is List || (value is Map && value['items'] is List)) {
      return _asJsonList(value);
    }
    throw SyncException(
      SyncErrorCode.loadFailed,
      cause: FormatException('Unexpected $entity response shape'),
    );
  }

  List<Map<String, dynamic>> _asJsonList(dynamic value) {
    if (value is Map && value['items'] is List) {
      return (value['items'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
}
