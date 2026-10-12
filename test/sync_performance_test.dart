import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/sync_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

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

    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
    LanguageManager.initFallback();
    await LocalDbService.init();
  });

  group('Sync Pagination Progress and Limit Tests', () {
    late ApiService api;

    setUp(() async {
      api = ApiService.instance;
      await api.setTokens('test_token', 'test_refresh');
    });

    test('syncBackendDataToLocal reports progress and pages correctly',
        () async {
      final progressUpdates = <Map<String, int>>[];

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions/')) {
            final cursor = options.queryParameters['cursor'];
            if (cursor == null) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'success',
                  'data': {
                    'items': [
                      {
                        'id': 'tx-1',
                        'amount': 100.0,
                        'description': 'Item 1',
                        'category': 'food',
                        'type': 'expense',
                        'date': '2026-10-01T10:00:00Z',
                      },
                      {
                        'id': 'tx-2',
                        'amount': 200.0,
                        'description': 'Item 2',
                        'category': 'salary',
                        'type': 'income',
                        'date': '2026-10-02T10:00:00Z',
                      },
                    ],
                    'has_more': true,
                    'next_cursor': 'cursor-page-2',
                  },
                },
              ));
            } else if (cursor == 'cursor-page-2') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'success',
                  'data': {
                    'items': [
                      {
                        'id': 'tx-3',
                        'amount': 300.0,
                        'description': 'Item 3',
                        'category': 'entertainment',
                        'type': 'expense',
                        'date': '2026-10-03T10:00:00Z',
                      },
                    ],
                    'has_more': false,
                  },
                },
              ));
            }
          } else if (options.path.contains('/budgets/')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': <Map<String, dynamic>>[],
              },
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        final result = await api.syncBackendDataToLocal(
          null,
          (count, page) {
            progressUpdates.add({'count': count, 'page': page});
          },
        );

        expect(result['transactions'], 3);
        expect(progressUpdates.length, 2);
        expect(progressUpdates[0], {'count': 2, 'page': 1});
        expect(progressUpdates[1], {'count': 3, 'page': 2});
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test('maxPages limit prevents unbounded pagination during transaction sync',
        () async {
      int fetchCount = 0;

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions/')) {
            fetchCount++;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': {
                  'items': [
                    {
                      'id': 'tx-$fetchCount',
                      'amount': 50.0,
                      'description': 'Paginated item $fetchCount',
                      'category': 'food',
                      'type': 'expense',
                      'date': '2026-10-01T10:00:00Z',
                    },
                  ],
                  'has_more': true,
                  'next_cursor': 'cursor-$fetchCount',
                },
              },
            ));
          } else if (options.path.contains('/budgets/')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'status': 'success', 'data': <Map<String, dynamic>>[]},
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        final result = await api.syncBackendDataToLocal(
          null,
          null,
          1, // Cap at 1 page
        );

        expect(fetchCount, 1);
        expect(result['transactions'], 1);
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

  group('Block A Sync Robustness Tests (A1, A2, A3, A6, E1)', () {
    late ApiService api;

    setUp(() async {
      api = ApiService.instance;
      await api.setTokens('test_token', 'test_refresh');
      await api.sync.clearEtags();
      final all = LocalDbService.instance.getAllTransactions();
      for (final t in all) {
        LocalDbService.instance.deleteTransaction(t.localId);
      }
    });

    test(
        'E1 / A1: error on page 2 does not save ETag and does not delete local transactions',
        () async {
      final db = LocalDbService.instance;
      final localTx = Transaction(
        localId: 0,
        serverId: 'tx-local-persistent',
        amount: 250.0,
        description: 'Should not be deleted',
        dbCategory: Category.food.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
        dateCreatedMilliseconds:
            DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
        isModified: false,
      );
      db.saveTransaction(localTx);
      expect(db.hasTransactions, isTrue);

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions')) {
            final cursor = options.queryParameters['cursor'];
            if (cursor == null) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                headers: Headers.fromMap({
                  'etag': ['etag-page1'],
                }),
                data: {
                  'status': 'success',
                  'data': {
                    'items': [
                      {
                        'id': 'tx-remote-1',
                        'amount': 100.0,
                        'description': 'Page 1 Item',
                        'category': 'food',
                        'type': 'expense',
                        'date': '2026-10-01T10:00:00Z',
                      }
                    ],
                    'has_more': true,
                    'next_cursor': 'cur_fail',
                  },
                },
              ));
            } else if (cursor == 'cur_fail') {
              return handler.reject(DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 500,
                ),
              ));
            }
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        await expectLater(
          api.sync.syncBackendDataToLocal('test_token'),
          throwsA(isA<SyncException>()),
        );

        // Проверяем A1: ETag не был сохранен
        expect(api.sync.transactionsEtag, isNot('etag-page1'));

        // Проверяем A2: локальная запись не была удалена
        final remaining = db.getAllTransactions();
        expect(
            remaining.any((t) => t.serverId == 'tx-local-persistent'), isTrue);
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test(
        'A2: reaching maxPages with hasMore=true performs upsert only without deleting records or saving ETag',
        () async {
      final db = LocalDbService.instance;
      final localTx = Transaction(
        localId: 0,
        serverId: 'tx-local-kept',
        amount: 300.0,
        description: 'Should remain on partial sync',
        dbCategory: Category.transport.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.utc(2026, 10, 2).millisecondsSinceEpoch,
        dateCreatedMilliseconds:
            DateTime.utc(2026, 10, 2).millisecondsSinceEpoch,
        isModified: false,
      );
      db.saveTransaction(localTx);

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              headers: Headers.fromMap({
                'etag': ['etag-partial'],
              }),
              data: {
                'status': 'success',
                'data': {
                  'items': [
                    {
                      'id': 'tx-remote-partial',
                      'amount': 50.0,
                      'description': 'Partial item',
                      'category': 'food',
                      'type': 'expense',
                      'date': '2026-10-02T10:00:00Z',
                    }
                  ],
                  'has_more': true,
                  'next_cursor': 'cur_never_loaded',
                },
              },
            ));
          }
          if (options.path.contains('/budgets')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': [],
              },
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        final result =
            await api.sync.syncBackendDataToLocal('test_token', null, 1);
        expect(result['removed_transactions'], 0);
        expect(api.sync.transactionsEtag, isNull);

        final all = db.getAllTransactions();
        final ids = all.map((t) => t.serverId).toSet();
        expect(ids.contains('tx-local-kept'), isTrue);
        expect(ids.contains('tx-remote-partial'), isTrue);
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test('A3: If-None-Match is NOT sent when local database is empty',
        () async {
      final db = LocalDbService.instance;
      expect(db.hasTransactions, isFalse);

      Map<String, dynamic>? capturedHeaders;

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions')) {
            capturedHeaders = options.headers;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': {
                  'items': [],
                  'has_more': false,
                },
              },
            ));
          }
          if (options.path.contains('/budgets')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': [],
              },
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        await api.sync.syncBackendDataToLocal('test_token');
        expect(capturedHeaders, isNotNull);
        expect(capturedHeaders!.containsKey('If-None-Match'), isFalse);
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test(
        'A6: Unauthenticated sync throws SyncException and maps to localized string',
        () async {
      await api.auth.setTokens(null, null);
      await expectLater(
        api.sync.syncLocalDataToBackend(null),
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
