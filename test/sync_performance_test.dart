import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/sync_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/config/environment.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});

    final tempDir = await Directory.systemTemp.createTemp('sync_perf_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
    LanguageManager.initFallback();
    await LocalDbService.init();
  });

  const serverTime = '2026-11-06T10:00:00.000Z';

  Map<String, dynamic> txJson(String id, {double amount = 100}) => {
        'id': id,
        'amount': amount,
        'description': 'Item $id',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-01T10:00:00Z',
      };

  /// Ответ `GET /sync/changes`.
  Response<dynamic> changes(
    RequestOptions options,
    List<Map<String, dynamic>> items, {
    List<String> deleted = const [],
    String? nextCursor,
    String time = serverTime,
  }) =>
      Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'status': 'success',
          'data': {
            'transactions': items,
            'deleted_transaction_ids': deleted,
            'has_more': nextCursor != null,
            'next_cursor': nextCursor,
            'server_time': time,
          },
        },
      );

  Response<dynamic> noBudgets(RequestOptions options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {'status': 'success', 'data': <Map<String, dynamic>>[]},
      );

  /// Подменяет сервер на время [body]: [onChanges] отвечает на
  /// `/sync/changes`, лимиты — пустой список.
  Future<void> withServer(
    ApiService api,
    Response<dynamic> Function(RequestOptions options) onChanges,
    Future<void> Function() body,
  ) async {
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/sync/changes') {
          return handler.resolve(onChanges(options));
        }
        if (options.path.contains('/budgets')) {
          return handler.resolve(noBudgets(options));
        }
        return handler.next(options);
      },
    );
    api.dio.interceptors.insert(0, interceptor);
    try {
      await body();
    } finally {
      api.dio.interceptors.remove(interceptor);
    }
  }

  Transaction syncedLocal(String serverId, {bool isModified = false}) =>
      Transaction(
        serverId: serverId,
        amount: 250.0,
        description: 'Local $serverId',
        dbCategory: Category.food.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
        dateCreatedMilliseconds:
            DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
        isModified: isModified,
      );

  Set<String?> localServerIds() => LocalDbService.instance
      .getAllTransactions()
      .map((t) => t.serverId)
      .toSet();

  group('Загрузка операций через /sync/changes', () {
    late ApiService api;

    setUp(() async {
      api = ApiService.instance;
      await api.auth.setTokens('test_token', 'test_refresh');
      await api.sync.clearEtags();
      await LocalDbService.instance.clearAllData();
    });

    test(
        'полная загрузка: все страницы, один сигнал экранам, отметка сохраняется',
        () async {
      final requests = <RequestOptions>[];
      await withServer(api, (options) {
        requests.add(options);
        return options.queryParameters['cursor'] == null
            ? changes(options, [txJson('tx-1'), txJson('tx-2')],
                nextCursor: 'page-2')
            : changes(options, [txJson('tx-3')],
                time: '2026-11-06T10:00:05.000Z');
      }, () async {
        final changesBefore = LocalDbService.transactionsChanged.value;

        final result = await api.sync.syncBackendDataToLocal();

        expect(result['transactions'], 3);
        expect(localServerIds(), {'tx-1', 'tx-2', 'tx-3'});
        expect(LocalDbService.transactionsChanged.value, changesBefore + 1);
        // Первая синхронизация — без since; отметка — время первой страницы
        expect(requests.first.queryParameters.containsKey('since'), isFalse);
        expect(requests[1].queryParameters['cursor'], 'page-2');
        expect(api.sync.changesSince, DateTime.parse(serverTime));
      });
    });

    test('maxPages ограничивает загрузку, отметка не сохраняется', () async {
      var fetchCount = 0;
      await withServer(api, (options) {
        fetchCount++;
        return changes(options, [txJson('tx-$fetchCount')],
            nextCursor: 'cursor-$fetchCount');
      }, () async {
        final result = await api.sync.syncBackendDataToLocal(maxPages: 1);

        expect(fetchCount, 1);
        expect(result['transactions'], 1);
        expect(api.sync.changesSince, isNull);
      });
    });

    test('с отметкой запрашиваются только изменения: правка и удаление',
        () async {
      final db = LocalDbService.instance;
      // Первая синхронизация ставит отметку
      await withServer(
        api,
        (options) => changes(options, [
          txJson('tx-edit'),
          txJson('tx-gone'),
          txJson('tx-kept'),
        ]),
        () => api.sync.syncBackendDataToLocal(),
      );
      // Локальная правка удалённой на сервере операции не теряется
      final kept = db.getAllTransactions().firstWhere(
            (t) => t.serverId == 'tx-kept',
          )..isModified = true;
      db.putTransactions([kept]);

      RequestOptions? request;
      await withServer(api, (options) {
        request = options;
        return changes(options, [txJson('tx-edit', amount: 999)],
            deleted: ['tx-gone', 'tx-kept'], time: '2026-11-06T11:00:00.000Z');
      }, () async {
        final result = await api.sync.syncBackendDataToLocal();

        expect(request!.queryParameters['since'], serverTime);
        expect(result['deleted_transactions'], 2);
        expect(result['removed_transactions'], 1);
      });

      final byId = {for (final t in db.getAllTransactions()) t.serverId: t};
      expect(byId.keys.toSet(), {'tx-edit', 'tx-kept'});
      expect(byId['tx-edit']!.amount, 999);
      expect(api.sync.changesSince, DateTime.parse('2026-11-06T11:00:00Z'));
    });

    test('нет изменений — экраны не перечитывают данные', () async {
      LocalDbService.instance.saveTransaction(syncedLocal('tx-1'));
      await withServer(
        api,
        (options) => changes(options, [txJson('tx-1')]),
        () => api.sync.syncBackendDataToLocal(),
      );

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/sync/changes') {
            return handler.resolve(changes(options, const []));
          }
          if (options.path.contains('/budgets')) {
            return handler
                .resolve(Response(requestOptions: options, statusCode: 304));
          }
          return handler.next(options);
        },
      );
      api.dio.interceptors.insert(0, interceptor);
      final changesBefore = LocalDbService.transactionsChanged.value;
      try {
        await api.sync.syncBackendDataToLocal();
        expect(LocalDbService.transactionsChanged.value, changesBefore);
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test('с пустой базой загрузка полная, даже если отметка есть', () async {
      await withServer(
        api,
        (options) => changes(options, [txJson('tx-1')]),
        () => api.sync.syncBackendDataToLocal(),
      );
      await LocalDbService.instance.clearAllData();

      RequestOptions? request;
      await withServer(api, (options) {
        request = options;
        return changes(options, [txJson('tx-1')]);
      }, () => api.sync.syncBackendDataToLocal());

      expect(request!.queryParameters.containsKey('since'), isFalse);
      expect(localServerIds(), {'tx-1'});
    });

    test('ошибка на второй странице: отметка не сохраняется, данные целы',
        () async {
      LocalDbService.instance.saveTransaction(syncedLocal('tx-local'));

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/sync/changes') {
            if (options.queryParameters['cursor'] == null) {
              return handler.resolve(changes(options, [txJson('tx-remote')],
                  nextCursor: 'cur_fail'));
            }
            return handler.reject(DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: options, statusCode: 500),
            ));
          }
          return handler.next(options);
        },
      );
      api.dio.interceptors.insert(0, interceptor);
      try {
        await expectLater(
          api.sync.syncBackendDataToLocal(),
          throwsA(isA<SyncException>()),
        );
        expect(api.sync.changesSince, isNull);
        expect(localServerIds(), contains('tx-local'));
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test('неполная полная загрузка — только upsert, без удаления локальных',
        () async {
      LocalDbService.instance.saveTransaction(syncedLocal('tx-local-kept'));

      await withServer(
        api,
        (options) => changes(options, [txJson('tx-remote-partial')],
            nextCursor: 'cur_never_loaded'),
        () async {
          final result = await api.sync.syncBackendDataToLocal(maxPages: 1);
          expect(result['removed_transactions'], 0);
        },
      );

      expect(localServerIds(),
          containsAll(['tx-local-kept', 'tx-remote-partial']));
      expect(api.sync.changesSince, isNull);
    });

    test('ответ без transactions — ошибка, база не трогается', () async {
      LocalDbService.instance.saveTransaction(syncedLocal('tx-1'));
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/sync/changes') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': {'unexpected': true},
              },
            ));
          }
          return handler.next(options);
        },
      );
      api.dio.interceptors.insert(0, interceptor);
      try {
        await expectLater(
          api.sync.syncBackendDataToLocal(),
          throwsA(isA<SyncException>()),
        );
        expect(localServerIds(), {'tx-1'});
        expect(api.sync.changesSince, isNull);
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });
  });

  group('LocalDbService Targeted Query Reconciliation Tests', () {
    setUp(() async {
      await LocalDbService.instance.clearAllData();
    });

    test(
        'reconcileTransactions cleans stale records via query and preserves local data',
        () {
      final db = LocalDbService.instance;

      // 1. Unsynced local item (serverId == null)
      final unsynced = Transaction.fromJson({
        'amount': 100.0,
        'description': 'Local unsynced',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-01T10:00:00Z',
      });
      db.saveTransaction(unsynced);

      // 2. Modified item (isModified == true)
      final modified = Transaction.fromJson({
        'id': 'srv-mod',
        'amount': 200.0,
        'description': 'Locally modified',
        'category': 'transport',
        'type': 'expense',
        'date': '2026-10-01T10:00:00Z',
      })
        ..isModified = true;
      db.saveTransaction(modified);

      // 3. Stale synced item (present locally, but missing on server)
      final stale = Transaction.fromJson({
        'id': 'srv-stale',
        'amount': 300.0,
        'description': 'Stale remote item',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-01T10:00:00Z',
      });
      db.saveTransaction(stale);

      // 4. Still valid remote item
      final valid = Transaction.fromJson({
        'id': 'srv-valid',
        'amount': 400.0,
        'description': 'Valid remote item',
        'category': 'salary',
        'type': 'income',
        'date': '2026-10-01T10:00:00Z',
      });
      db.saveTransaction(valid);

      // Reconcile with remote containing 'srv-valid' and 'srv-new'
      final remote = [
        Transaction.fromJson({
          'id': 'srv-valid',
          'amount': 450.0,
          'description': 'Valid updated',
          'category': 'salary',
          'type': 'income',
          'date': '2026-10-01T10:00:00Z',
        }),
        Transaction.fromJson({
          'id': 'srv-new',
          'amount': 500.0,
          'description': 'Brand new remote',
          'category': 'salary',
          'type': 'income',
          'date': '2026-10-01T10:00:00Z',
        }),
      ];

      final removedCount = db.reconcileTransactions(remote);
      expect(removedCount, 1); // Only srv-stale was removed

      final all = db.getAllTransactions();
      final serverIds = all.map((t) => t.serverId).toSet();

      expect(serverIds.contains('srv-stale'), isFalse);
      expect(serverIds.contains('srv-valid'), isTrue);
      expect(serverIds.contains('srv-new'), isTrue);
      expect(serverIds.contains('srv-mod'), isTrue);
      expect(all.any((t) => t.description == 'Local unsynced'), isTrue);
    });

    test(
        'applyRemoteTransactionChanges: правка, удаление, локальные изменения и дубль невыгруженной',
        () {
      final db = LocalDbService.instance;
      Transaction tx(String? id, double amount, {bool modified = false}) =>
          Transaction.fromJson({
            if (id != null) 'id': id,
            'amount': amount,
            'description': 'tx $id',
            'category': 'food',
            'type': 'expense',
            'date': '2026-10-01T10:00:00Z',
          })
            ..isModified = modified;

      db.saveTransaction(tx('srv-edit', 1));
      db.saveTransaction(tx('srv-gone', 2));
      db.saveTransaction(tx('srv-mod', 3, modified: true));
      // Невыгруженная запись, которую сервер уже принял (ответ /sync потерян)
      db.saveTransaction(tx(null, 4));

      final removed = db.applyRemoteTransactionChanges(
        [tx('srv-edit', 10), tx('srv-mod', 30), tx('srv-twin', 4)],
        ['srv-gone', 'srv-mod', 'srv-unknown'],
      );

      expect(removed, 1);
      final all = db.getAllTransactions();
      final byId = {for (final t in all) t.serverId: t};
      expect(all, hasLength(3));
      expect(byId['srv-edit']!.amount, 10);
      expect(byId['srv-mod']!.amount, 3);
      expect(byId['srv-twin']!.amount, 4);
      expect(byId.containsKey('srv-gone'), isFalse);
    });

    test(
        'reconcileBudgets cleans stale records via query and preserves local data',
        () {
      final db = LocalDbService.instance;

      final staleBudget = Budget.fromJson({
        'id': 'bg-stale',
        'category': 'food',
        'limit_amount': 1000.0,
        'month': 10,
        'year': 2026,
      });
      db.saveBudget(staleBudget);

      final validBudget = Budget.fromJson({
        'id': 'bg-valid',
        'category': 'transport',
        'limit_amount': 500.0,
        'month': 10,
        'year': 2026,
      });
      db.saveBudget(validBudget);

      final remote = [
        Budget.fromJson({
          'id': 'bg-valid',
          'category': 'transport',
          'limit_amount': 600.0,
          'month': 10,
          'year': 2026,
        }),
      ];

      final removedCount = db.reconcileBudgets(remote);
      expect(removedCount, 1);

      final all = db.getAllBudgets();
      expect(all.length, 1);
      expect(all.first.serverId, 'bg-valid');
      expect(all.first.limitAmount, 600.0);
    });
  });

  group('Без сессии', () {
    late ApiService api;

    setUp(() => api = ApiService.instance);

    test(
        'A6: Unauthenticated sync throws SyncException and maps to localized string',
        () async {
      await api.auth.setTokens(null, null);
      await expectLater(
        api.sync.syncLocalDataToBackend(),
        throwsA(
          predicate<SyncException>((e) {
            expect(e.code, SyncErrorCode.unauthorized);
            final msg = AppErrorHandler.getMessage(e);
            expect(msg, LanguageManager.l10n.sync_login_required);
            return true;
          }),
        ),
      );
    });
  });
}
