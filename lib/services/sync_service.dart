import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';
import 'transaction_api_service.dart';
import 'budget_api_service.dart';

/// Сервис синхронизации локальных данных с сервером.
class SyncService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Options Function([String? token]) _authOptions;
  final String? Function() _tokenProvider;
  final TransactionApiService _transactionApiService;
  final BudgetApiService _budgetApiService;

  String? _transactionsEtag;
  String? _budgetsEtag;

  SyncService({
    required Dio dio,
    required Options Function([String? token]) authOptions,
    required String? Function() tokenProvider,
    required TransactionApiService transactionApiService,
    required BudgetApiService budgetApiService,
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  })  : _dio = dio,
        _authOptions = authOptions,
        _tokenProvider = tokenProvider,
        _transactionApiService = transactionApiService,
        _budgetApiService = budgetApiService,
        _storage = storage;

  Future<void> init() async {
    _transactionsEtag = await _storage.read(key: 'transactions_etag');
    _budgetsEtag = await _storage.read(key: 'budgets_etag');
  }

  Future<void> clearEtags() async {
    _transactionsEtag = null;
    _budgetsEtag = null;
  }

  /// Выгружает локальные транзакции и бюджеты на сервер.
  Future<Map<String, dynamic>> syncLocalDataToBackend([String? token]) async {
    final jwtToken = token ?? _tokenProvider();
    if (jwtToken == null) throw Exception('Не авторизован');

    try {
      final localTransactions =
          LocalDbService.instance.getUnsyncedTransactions();
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

      final budgetsPayload = <Map<String, dynamic>>[];
      for (final b in localBudgets) {
        budgetsPayload.add(b.toJson());
      }
      for (final budgetId in pendingBudgets) {
        budgetsPayload.add({
          'id': budgetId,
          'is_deleted': true,
        });
      }

      final payload = SyncModel(
        transactions: localTransactions.map((t) => t.toJson()).toList(),
        budgets: budgetsPayload,
        deletedBudgetIds: pendingBudgets.isNotEmpty ? pendingBudgets : null,
        deletedTransactionIds:
            pendingTransactions.isNotEmpty ? pendingTransactions : null,
      );

      final response = await _dio.post(
        ApiConfig.sync,
        data: payload.toJson(),
        options: _authOptions(jwtToken),
      );

      final data = response.data['data'];

      if (data is Map) {
        _assignTransactionIds(localTransactions, data['synced_transactions']);
        _assignBudgetIds(localBudgets, data['synced_budgets']);
      }

      if (pendingBudgets.isNotEmpty) {
        await PendingDeletionsStore.instance.removeBudgets(pendingBudgets);
      }
      if (pendingTransactions.isNotEmpty) {
        await PendingDeletionsStore.instance
            .removeTransactions(pendingTransactions);
      }

      AppLogger.i('[SyncService] Sync local -> backend success');
      return data is Map ? data.cast<String, dynamic>() : response.data;
    } on DioException catch (e) {
      AppLogger.e('[SyncService] Sync error: ${e.response?.statusCode}', e);
      throw Exception('Ошибка синхронизации: ${e.response?.statusCode}');
    } catch (e) {
      AppLogger.e('[SyncService] Sync unexpected error', e);
      rethrow;
    }
  }

  /// Загружает транзакции и бюджеты пользователя с сервера в локальную базу.
  Future<Map<String, dynamic>> syncBackendDataToLocal([
    String? token,
    void Function(int count, int page)? onTransactionProgress,
    int maxPages = 100,
  ]) async {
    final jwtToken = token ?? _tokenProvider();
    if (jwtToken == null) throw Exception('Не авторизован');

    try {
      final remoteTransactions = await _fetchRemoteTransactions(
        jwtToken,
        onProgress: onTransactionProgress,
        maxPages: maxPages,
      );
      final remoteBudgets = await _fetchRemoteBudgets(jwtToken);

      int removedTransactions = 0;
      int transLength = 0;
      if (remoteTransactions != null) {
        removedTransactions =
            LocalDbService.instance.reconcileTransactions(remoteTransactions);
        transLength = remoteTransactions.length;
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
      } else {
        AppLogger.i(
            '[SyncService] Budgets not modified (304). Skipping reconciliation.');
        budgetsLength = LocalDbService.instance.getAllBudgets().length;
      }

      AppLogger.i('[SyncService] Sync backend -> local: '
          'T($transLength), B($budgetsLength); '
          'Removed: T($removedTransactions), B($removedBudgets)');

      return {
        'transactions': transLength,
        'budgets': budgetsLength,
        'removed_transactions': removedTransactions,
        'removed_budgets': removedBudgets,
      };
    } on DioException catch (e) {
      AppLogger.e('[SyncService] Load error: ${e.response?.statusCode}', e);
      throw Exception('Ошибка загрузки данных: ${e.response?.statusCode}');
    } catch (e) {
      AppLogger.e('[SyncService] Load unexpected error', e);
      rethrow;
    }
  }

  /// Полная двусторонняя синхронизация.
  Future<Map<String, dynamic>> syncAll([
    String? token,
    void Function(int count, int page)? onTransactionProgress,
    int maxPages = 100,
  ]) async {
    final jwtToken = token ?? _tokenProvider();
    if (jwtToken == null) throw Exception('Не авторизован');

    final deleted = await _flushPendingDeletions(jwtToken);
    final pushed = await syncLocalDataToBackend(jwtToken);
    final pulled = await syncBackendDataToLocal(
      jwtToken,
      onTransactionProgress,
      maxPages,
    );

    return {'deleted': deleted, 'pushed': pushed, 'pulled': pulled};
  }

  Future<int> _flushPendingDeletions(String token) async {
    final pendingTransactions = PendingDeletionsStore.instance.transactionIds;
    final pendingBudgets = PendingDeletionsStore.instance.budgetIds;

    if (pendingTransactions.isEmpty && pendingBudgets.isEmpty) return 0;

    int totalDone = 0;

    if (pendingTransactions.isNotEmpty) {
      final done = <String>[];
      for (final serverId in pendingTransactions) {
        try {
          await _transactionApiService.deleteTransaction(serverId, token);
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
          await _budgetApiService.deleteBudget(serverId, token);
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

  Future<List<Transaction>?> _fetchRemoteTransactions(
    String token, {
    DateTime? since,
    void Function(int count, int page)? onProgress,
    int maxPages = 100,
  }) async {
    final options = _authOptions(token);
    options.validateStatus = (status) =>
        status != null && ((status >= 200 && status < 300) || status == 304);
    if (_transactionsEtag != null) {
      options.headers?['If-None-Match'] = _transactionsEtag;
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
      return null;
    }

    final newEtag = firstResponse.headers.value('etag');
    if (newEtag != null) {
      _transactionsEtag = newEtag;
      await _storage.write(key: 'transactions_etag', value: newEtag);
    }

    final firstData =
        firstResponse.data is Map ? firstResponse.data['data'] : null;
    final firstItems = _asJsonList(firstData);
    allTransactions.addAll(firstItems.map(Transaction.fromJson));
    onProgress?.call(allTransactions.length, 1);

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
          options: _authOptions(token),
        );

        final nextData =
            nextResponse.data is Map ? nextResponse.data['data'] : null;
        final nextItems = _asJsonList(nextData);
        if (nextItems.isEmpty) break;

        allTransactions.addAll(nextItems.map(Transaction.fromJson));
        onProgress?.call(allTransactions.length, page);

        if (nextData is Map) {
          hasMore = nextData['has_more'] == true;
          currentCursor = nextData['next_cursor'] as String?;
        } else {
          hasMore = false;
        }
      }

      if (page >= maxPages && hasMore) {
        AppLogger.w(
            '[SyncService] Transaction pagination limit ($maxPages pages) reached.');
      }
    }

    return allTransactions;
  }

  Future<List<Budget>?> _fetchRemoteBudgets(String token) async {
    final options = _authOptions(token);
    options.validateStatus = (status) =>
        status != null && ((status >= 200 && status < 300) || status == 304);

    if (_budgetsEtag != null) {
      options.headers?['If-None-Match'] = _budgetsEtag;
    }

    final response = await _dio.get(
      ApiConfig.budgets,
      options: options,
    );

    if (response.statusCode == 304) {
      return null;
    }

    final newEtag = response.headers.value('etag');
    if (newEtag != null) {
      _budgetsEtag = newEtag;
      await _storage.write(key: 'budgets_etag', value: newEtag);
    }

    return _asJsonList(response.data['data'])
        .map(Budget.fromJson)
        .where((b) => b.isValidPeriod)
        .toList();
  }

  void _assignTransactionIds(List<Transaction> sent, dynamic remote) {
    final remoteItems = _asJsonList(remote);
    if (remoteItems.isEmpty) {
      final synced = <Transaction>[];
      for (final local in sent) {
        if (local.isModified) {
          local.isModified = false;
          synced.add(local);
        }
      }
      if (synced.isNotEmpty) {
        LocalDbService.instance.putTransactions(synced);
      }
      return;
    }

    final synced = <Transaction>[];

    if (remoteItems.length == sent.length) {
      for (var i = 0; i < sent.length; i++) {
        final id = remoteItems[i]['id'];

        if (id is String) {
          sent[i].serverId = id;
          sent[i].isModified = false;
          synced.add(sent[i]);
        }
      }
    } else {
      final byId = <String, Map<String, dynamic>>{};
      final byKey = <String, Map<String, dynamic>>{};

      for (final json in remoteItems) {
        final id = json['id'];
        if (id is String) {
          byId[id] = json;
        }
        byKey[_remoteTransactionKey(json)] = json;
      }
      for (final local in sent) {
        if (local.serverId != null && byId.containsKey(local.serverId)) {
          local.isModified = false;
          synced.add(local);
        } else {
          final matchedJson = byKey[_localTransactionKey(local)];
          final id = matchedJson?['id'];

          if (id is String) {
            local.serverId = id;
            local.isModified = false;
            synced.add(local);
          } else if (local.serverId != null) {
            local.isModified = false;
            synced.add(local);
          }
        }
      }
    }

    LocalDbService.instance.putTransactions(synced);
    AppLogger.d(
        '[SyncService] Assigned transaction IDs: ${synced.length}/${sent.length}');
  }

  void _assignBudgetIds(List<Budget> sent, dynamic remote) {
    final remoteItems = _asJsonList(remote);
    if (remoteItems.isEmpty) {
      final synced = <Budget>[];
      for (final local in sent) {
        if (local.isModified) {
          local.isModified = false;
          synced.add(local);
        }
      }
      if (synced.isNotEmpty) {
        LocalDbService.instance.putBudgets(synced);
      }
      return;
    }

    final synced = <Budget>[];

    if (remoteItems.length == sent.length) {
      for (var i = 0; i < sent.length; i++) {
        final id = remoteItems[i]['id'];

        if (id is String) {
          sent[i].serverId = id;
          sent[i].isModified = false;
          synced.add(sent[i]);
        }
      }
    } else {
      final byId = <String, Map<String, dynamic>>{};
      final byKey = <String, Map<String, dynamic>>{};

      for (final json in remoteItems) {
        final id = json['id'];
        if (id is String) {
          byId[id] = json;
        }
        byKey['${json['category']}|${json['month']}|${json['year']}'] = json;
      }
      for (final local in sent) {
        if (local.serverId != null && byId.containsKey(local.serverId)) {
          local.isModified = false;
          synced.add(local);
        } else {
          final matchedJson =
              byKey['${local.category.name}|${local.month}|${local.year}'];
          final id = matchedJson?['id'];

          if (id is String) {
            local.serverId = id;
            local.isModified = false;
            synced.add(local);
          } else if (local.serverId != null) {
            local.isModified = false;
            synced.add(local);
          }
        }
      }
    }

    LocalDbService.instance.putBudgets(synced);
    AppLogger.d(
        '[SyncService] Assigned budget IDs: ${synced.length}/${sent.length}');
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

  String _remoteTransactionKey(Map<String, dynamic> json) {
    final date = parseServerDate(json['date']) ??
        DateTime.parse(json['date'] as String).toLocal();

    return '${parseAmount(json['amount'])}|${json['category']}|'
        '${json['type']}|${date.millisecondsSinceEpoch}';
  }

  String _localTransactionKey(Transaction t) {
    return '${t.amount}|${t.category.name}|${t.type.name}|'
        '${t.date.millisecondsSinceEpoch}';
  }
}
