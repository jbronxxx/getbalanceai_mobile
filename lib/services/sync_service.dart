import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show mapEquals;
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
import 'transaction_api_service.dart';
import 'budget_api_service.dart';

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

class _RemoteTransactionsFetchResult {
  final List<Transaction>? transactions;
  final bool isNotModified;
  final bool isComplete;
  final String? newEtag;

  const _RemoteTransactionsFetchResult({
    this.transactions,
    this.isNotModified = false,
    this.isComplete = true,
    this.newEtag,
  });
}

class _RemoteBudgetsFetchResult {
  final List<Budget>? budgets;
  final String? newEtag;

  const _RemoteBudgetsFetchResult({this.budgets, this.newEtag});
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
  final TransactionApiService _transactionApiService;
  final BudgetApiService _budgetApiService;

  static const _uuid = Uuid();

  /// Сколько записей каждого вида уходит в один запрос `/sync/`.
  ///
  /// Бэкенд принимает не больше 500 элементов в каждом списке батча и
  /// отвечает 422 на весь запрос, если их больше. 200 оставляет запас и
  /// держит тело запроса небольшим на медленной сети.
  static const syncBatchSize = 200;

  String? _transactionsEtag;
  String? _budgetsEtag;

  /// Хвост очереди синхронизации: каждая новая операция ждёт предыдущую.
  Future<void> _queueTail = Future.value();

  SyncService({
    required Dio dio,
    required Options Function([String? token]) authOptions,
    required String? Function() tokenProvider,
    String? Function()? userIdProvider,
    required TransactionApiService transactionApiService,
    required BudgetApiService budgetApiService,
    FlutterSecureStorage storage = appSecureStorage,
  })  : _dio = dio,
        _authOptions = authOptions,
        _tokenProvider = tokenProvider,
        _userIdProvider = userIdProvider,
        _transactionApiService = transactionApiService,
        _budgetApiService = budgetApiService,
        _storage = storage;

  String get _transactionsEtagKey => _etagKey('transactions');
  String get _budgetsEtagKey => _etagKey('budgets');

  String _etagKey(String entity, [String? userId]) {
    final owner = userId ?? _userIdProvider?.call() ?? 'anon';
    final env = EnvironmentConfig.current.name;
    return '${entity}_etag_${owner}_$env';
  }

  String? get transactionsEtag => _transactionsEtag;

  /// userId аккаунта, которому принадлежат операции и лимиты на устройстве.
  /// `null` — владельца нет: гостевые данные или база очищена при выходе.
  static const _localDataOwnerKey = 'local_data_owner';
  String? _localDataOwner;

  /// [stored] — содержимое хранилища, уже прочитанное одним `readAll()`
  /// (см. `AuthApiService.init`); без него хранилище читается здесь.
  Future<void> init([Map<String, String>? stored]) async {
    stored ??= await _storage.readAll();
    _transactionsEtag = stored[_transactionsEtagKey];
    _budgetsEtag = stored[_budgetsEtagKey];
    _localDataOwner = stored[_localDataOwnerKey];
  }

  /// Сбрасывает ETag пользователя [userId] (по умолчанию — текущего).
  /// Ключи привязаны к userId, поэтому при выходе его нужно передать явно
  /// или вызвать до очистки сессии.
  Future<void> clearEtags({String? userId}) async {
    _transactionsEtag = null;
    _budgetsEtag = null;
    try {
      await _storage.delete(key: _etagKey('transactions', userId));
      await _storage.delete(key: _etagKey('budgets', userId));
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
    void Function(int count, int page)? onTransactionProgress,
    int maxPages = 100,
  }) async {
    _requireSession();
    return _enqueue(() {
      _requireSession();
      return _pull(onTransactionProgress, maxPages);
    });
  }

  /// Полная двусторонняя синхронизация — одна задача в очереди: между
  /// выгрузкой и загрузкой не вклинится другой запрос.
  Future<Map<String, dynamic>> syncAll({
    void Function(int count, int page)? onTransactionProgress,
    int maxPages = 100,
  }) async {
    _requireSession();
    return _enqueue(() async {
      _requireSession();
      final deleted = await _flushPendingDeletions();
      final pushed = await _push();
      final pulled = await _pull(onTransactionProgress, maxPages);

      return {'deleted': deleted, 'pushed': pushed, 'pulled': pulled};
    });
  }

  Future<Map<String, dynamic>> _push() async {
    try {
      final localTransactions =
          LocalDbService.instance.getUnsyncedTransactions();
      _assignClientTransactionIds(localTransactions);
      final localBudgets = LocalDbService.instance.getUnsyncedBudgets();
      final pendingBudgets = PendingDeletionsStore.instance.budgetIds.toList();
      final pendingTransactions =
          PendingDeletionsStore.instance.transactionIds.toList();

      if (localTransactions.isEmpty &&
          localBudgets.isEmpty &&
          pendingBudgets.isEmpty &&
          pendingTransactions.isEmpty) {
        return {'message': 'Нет данных для синхронизации'};
      }

      final batches = [
        localTransactions.length,
        localBudgets.length,
        pendingBudgets.length,
        pendingTransactions.length,
      ].map((n) => (n / syncBatchSize).ceil()).reduce(math.max);

      var syncedTransactions = 0;
      var syncedBudgets = 0;
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
        final deletedBudgets = _batch(pendingBudgets, i);
        final deletedTransactions = _batch(pendingTransactions, i);

        // Удаление лимитов — только через `deleted_budget_ids`: элемент
        // `budgets` без категории и периода сервер отклоняет 422 вместе со
        // всем батчем.
        final payload = SyncModel(
          transactions: sentTransactions.values.toList(),
          budgets: sentBudgets.values.toList(),
          deletedBudgetIds: deletedBudgets,
          deletedTransactionIds: deletedTransactions,
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
            '(${rejected.map((r) => r['reason']).toSet().join('; ')})');
      }
      AppLogger.i('[SyncService] Sync local -> backend success: '
          'T($syncedTransactions/${localTransactions.length}), '
          'B($syncedBudgets/${localBudgets.length}), batches: $batches');
      return {
        'synced_transactions': syncedTransactions,
        'synced_budgets': syncedBudgets,
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

  Future<Map<String, dynamic>> _pull(
    void Function(int count, int page)? onTransactionProgress,
    int maxPages,
  ) async {
    try {
      final remoteTransactionsResult = await _fetchRemoteTransactions(
        onProgress: onTransactionProgress,
        maxPages: maxPages,
      );
      final remoteBudgetsResult = await _fetchRemoteBudgets();
      final remoteBudgets = remoteBudgetsResult.budgets;

      // ETag сохраняется только после того, как данные легли в базу: если
      // загрузка или сверка оборвётся раньше, следующий синк не получит 304
      // и не пропустит изменения с сервера.
      int removedTransactions = 0;
      int transLength = 0;
      if (remoteTransactionsResult.transactions != null) {
        if (remoteTransactionsResult.isComplete) {
          removedTransactions = LocalDbService.instance
              .reconcileTransactions(remoteTransactionsResult.transactions!);
        } else {
          LocalDbService.instance
              .upsertRemoteTransactions(remoteTransactionsResult.transactions!);
          removedTransactions = 0;
        }
        transLength = remoteTransactionsResult.transactions!.length;
        await _saveTransactionsEtag(remoteTransactionsResult.newEtag);
      } else {
        AppLogger.i(
            '[SyncService] Transactions not modified (304). Skipping reconciliation.');
        transLength = LocalDbService.instance.getAllTransactions().length;
      }

      int removedBudgets = 0;
      int budgetsLength = 0;
      if (remoteBudgets != null) {
        removedBudgets =
            LocalDbService.instance.reconcileBudgets(remoteBudgets);
        budgetsLength = remoteBudgets.length;
        await _saveBudgetsEtag(remoteBudgetsResult.newEtag);
      } else {
        AppLogger.i(
            '[SyncService] Budgets not modified (304). Skipping reconciliation.');
        budgetsLength = LocalDbService.instance.getAllBudgets().length;
      }

      AppLogger.i('[SyncService] Sync backend -> local: '
          'T($transLength), B($budgetsLength); '
          'Removed: T($removedTransactions), B($removedBudgets)');

      // Один сигнал на загрузку, и только если сервер прислал изменения
      // (не 304): экраны перечитают данные, но не на каждой записи в базу.
      if (remoteTransactionsResult.transactions != null ||
          remoteBudgets != null) {
        LocalDbService.transactionsChanged.value++;
      }

      return {
        'transactions': transLength,
        'budgets': budgetsLength,
        'removed_transactions': removedTransactions,
        'removed_budgets': removedBudgets,
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

  Future<void> _saveTransactionsEtag(String? etag) async {
    if (etag == null) return;
    _transactionsEtag = etag;
    await _storage.write(key: _transactionsEtagKey, value: etag);
  }

  Future<void> _saveBudgetsEtag(String? etag) async {
    if (etag == null) return;
    _budgetsEtag = etag;
    await _storage.write(key: _budgetsEtagKey, value: etag);
  }

  Future<int> _flushPendingDeletions() async {
    final pendingTransactions = PendingDeletionsStore.instance.transactionIds;
    final pendingBudgets = PendingDeletionsStore.instance.budgetIds;

    if (pendingTransactions.isEmpty && pendingBudgets.isEmpty) return 0;

    int totalDone = 0;

    if (pendingTransactions.isNotEmpty) {
      final done = <String>[];
      for (final serverId in pendingTransactions) {
        try {
          await _transactionApiService.deleteTransaction(serverId);
          done.add(serverId);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            done.add(serverId);
          } else {
            AppLogger.w(
                '[SyncService] Flush delete transaction $serverId failed: ${e.response?.statusCode}');
          }
        } catch (e) {
          AppLogger.w(
              '[SyncService] Flush delete transaction $serverId failed: $e');
        }
      }
      await PendingDeletionsStore.instance.removeTransactions(done);
      totalDone += done.length;
    }

    if (pendingBudgets.isNotEmpty) {
      final done = <String>[];
      for (final serverId in pendingBudgets) {
        try {
          await _budgetApiService.deleteBudget(serverId);
          done.add(serverId);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            done.add(serverId);
          } else {
            AppLogger.w(
                '[SyncService] Flush delete budget $serverId failed: ${e.response?.statusCode}');
          }
        } catch (e) {
          AppLogger.w('[SyncService] Flush delete budget $serverId failed: $e');
        }
      }
      await PendingDeletionsStore.instance.removeBudgets(done);
      totalDone += done.length;
    }

    if (totalDone > 0) {
      AppLogger.i('[SyncService] Flushed pending deletions: $totalDone');
    }

    return totalDone;
  }

  Future<_RemoteTransactionsFetchResult> _fetchRemoteTransactions({
    DateTime? since,
    void Function(int count, int page)? onProgress,
    int maxPages = 100,
  }) async {
    final options = _authOptions();
    options.validateStatus = (status) =>
        status != null && ((status >= 200 && status < 300) || status == 304);

    final hasLocal =
        LocalDbService.isInitialized && LocalDbService.instance.hasTransactions;
    if (!hasLocal) {
      _transactionsEtag = null;
    } else {
      _transactionsEtag ??= await _storage.read(key: _transactionsEtagKey);
      if (_transactionsEtag != null) {
        options.headers?['If-None-Match'] = _transactionsEtag;
      }
    }

    const pageSize = 100;
    String? currentCursor;
    final allTransactions = <Transaction>[];

    final firstResponse = await _dio.get(
      ApiConfig.transactions,
      queryParameters: {
        'limit': pageSize,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
      options: options,
    );

    if (firstResponse.statusCode == 304) {
      return const _RemoteTransactionsFetchResult(
        isNotModified: true,
        isComplete: true,
      );
    }

    final newEtag = firstResponse.headers.value('etag');
    final firstData =
        firstResponse.data is Map ? firstResponse.data['data'] : null;
    final firstItems = _requireJsonList(firstData, 'transactions');
    allTransactions.addAll(firstItems.map(Transaction.fromJson));
    onProgress?.call(allTransactions.length, 1);

    bool isComplete = true;

    if (firstData is Map) {
      bool hasMore = firstData['has_more'] == true;
      currentCursor = firstData['next_cursor'] as String?;
      int page = 1;

      while (hasMore && currentCursor != null && page < maxPages) {
        page++;
        final nextResponse = await _dio.get(
          ApiConfig.transactions,
          queryParameters: {
            'limit': pageSize,
            'cursor': currentCursor,
            if (since != null) 'since': since.toUtc().toIso8601String(),
          },
          options: _authOptions(),
        );

        final nextData =
            nextResponse.data is Map ? nextResponse.data['data'] : null;
        final nextItems = _requireJsonList(nextData, 'transactions');
        if (nextItems.isEmpty) {
          isComplete = false;
          break;
        }

        allTransactions.addAll(nextItems.map(Transaction.fromJson));
        onProgress?.call(allTransactions.length, page);

        if (nextData is Map) {
          hasMore = nextData['has_more'] == true;
          currentCursor = nextData['next_cursor'] as String?;
        } else {
          hasMore = false;
        }
      }

      if (hasMore) {
        isComplete = false;
        if (page >= maxPages) {
          AppLogger.w(
              '[SyncService] Transaction pagination limit ($maxPages pages) reached.');
        }
      }
    }

    // ETag годится только для полного списка; сохраняет его [_pull] после
    // сверки.
    return _RemoteTransactionsFetchResult(
      transactions: allTransactions,
      isComplete: isComplete,
      newEtag: isComplete ? newEtag : null,
    );
  }

  Future<_RemoteBudgetsFetchResult> _fetchRemoteBudgets() async {
    final options = _authOptions();
    options.validateStatus = (status) =>
        status != null && ((status >= 200 && status < 300) || status == 304);

    final hasLocalBudgets =
        LocalDbService.isInitialized && LocalDbService.instance.hasBudgets;
    if (!hasLocalBudgets) {
      _budgetsEtag = null;
    } else {
      _budgetsEtag ??= await _storage.read(key: _budgetsEtagKey);
      if (_budgetsEtag != null) {
        options.headers?['If-None-Match'] = _budgetsEtag;
      }
    }

    final response = await _dio.get(
      ApiConfig.budgets,
      options: options,
    );

    if (response.statusCode == 304) {
      return const _RemoteBudgetsFetchResult();
    }

    final data = response.data is Map ? response.data['data'] : null;
    return _RemoteBudgetsFetchResult(
      budgets: _requireJsonList(data, 'budgets')
          .map(Budget.fromJson)
          .where((b) => b.isValidPeriod)
          .toList(),
      newEtag: response.headers.value('etag'),
    );
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

  /// Причина отказа сервера по ID записи — `null`, если запись не отклонена.
  Map<String, String?> _rejectedReasons(List<Map<String, dynamic>> rejected) {
    return {
      for (final json in rejected)
        if (json['id'] is String)
          json['id'] as String: json['reason'] as String?,
    };
  }

  /// Сервер отклонил запись, потому что её ID принадлежит чужой записи.
  /// Повтор с тем же ID отклонялся бы вечно — запись нужно перевыпустить.
  static bool _isIdConflict(String? reason) =>
      reason != null && reason.contains('конфликт идентификатора');

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
  ///   при следующей выгрузке; прочие отказы остаются в очереди.
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
    final rejectedReasons = _rejectedReasons(rejected);

    final localIds = sent.keys.toList();
    final stored = LocalDbService.instance.getTransactionsByLocalIds(localIds);
    final toPut = <Transaction>[];
    var confirmed = 0;

    for (var i = 0; i < localIds.length; i++) {
      final row = stored[i];
      final snapshot = sent[localIds[i]]!;
      final sentId = snapshot['id'];
      if (row == null || sentId is! String || row.serverId != sentId) continue;

      if (confirmedIds.contains(sentId)) {
        confirmed++;
        if (row.isModified && mapEquals(row.toJson(), snapshot)) {
          row.isModified = false;
          toPut.add(row);
        }
      } else if (_isIdConflict(rejectedReasons[sentId])) {
        row
          ..serverId = _uuid.v4()
          ..isModified = true;
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
    final rejectedReasons = _rejectedReasons(rejected);

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
          (rejectedReasons.containsKey(sentId)
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
      } else if (_isIdConflict(rejectedReasons[sentId])) {
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
