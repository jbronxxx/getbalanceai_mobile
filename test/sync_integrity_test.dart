import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/profile/profile_cubit.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/budget_api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/pending_deletions_store.dart';
import 'package:getbalanceai_mobile/services/sync_service.dart';
import 'package:getbalanceai_mobile/services/transaction_api_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:getbalanceai_mobile/config/environment.dart';

class _MockApiService extends Mock implements ApiService {}

/// Сеть для [SyncService]: обработчик решает, что ответить на запрос, и
/// может придержать ответ, чтобы проверить, что происходит «во время»
/// запроса.
class _FakeAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  int inFlight = 0;
  int maxInFlight = 0;

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      return await handler(options);
    } finally {
      inFlight--;
    }
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200, String? etag]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (etag != null) 'etag': [etag],
      },
    );

/// Ответ `/sync/`, как у бэкенда: каждая отправленная запись возвращается
/// с тем же `id` (лимит без `id` получает новый).
ResponseBody _acceptAll(RequestOptions options, {bool reversed = false}) {
  final data = options.data as Map;
  var txs = (data['transactions'] as List).cast<Map>();
  var budgets = (data['budgets'] as List).cast<Map>();
  if (reversed) {
    txs = txs.reversed.toList();
    budgets = budgets.reversed.toList();
  }
  return _json({
    'status': 'success',
    'data': {
      'synced_transactions': [
        for (final t in txs) {...t, 'created_at': t['date']}
      ],
      'synced_budgets': [
        for (final b in budgets) {...b, 'id': b['id'] ?? 'srv-${b['category']}'}
      ],
      'rejected': [],
    },
  });
}

void main() {
  late _FakeAdapter adapter;
  late SyncService sync;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});

    final tempDir = await Directory.systemTemp.createTemp('sync_integrity');
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

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await LocalDbService.instance.clearAllData();
    await PendingDeletionsStore.instance.clear();

    adapter = _FakeAdapter((options) async => _acceptAll(options));
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    Options authOptions([String? token]) =>
        Options(headers: {'Authorization': 'Bearer $token'});
    sync = SyncService(
      dio: dio,
      authOptions: authOptions,
      tokenProvider: () => 'token',
      transactionApiService: TransactionApiService(
        dio: dio,
        authOptions: authOptions,
        isAuthenticated: () => true,
      ),
      budgetApiService: BudgetApiService(
        dio: dio,
        authOptions: authOptions,
        isAuthenticated: () => true,
      ),
    );
  });

  LocalDbService db() => LocalDbService.instance;

  var dayOffset = 0;
  Transaction newTransaction({double amount = 50000}) => Transaction(
        amount: amount,
        description: 'Обед',
        dbCategory: 'food',
        dbType: 'expense',
        // Разные даты — чтобы записи не совпадали по содержимому.
        dateMilliseconds: DateTime(2026, 1, 1)
            .add(Duration(minutes: dayOffset++))
            .millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        currencyCode: 'UZS',
      );

  Transaction addTransaction({double amount = 50000}) {
    final t = newTransaction(amount: amount);
    db().saveTransaction(t);
    return t;
  }

  Budget addBudget(String category, {double limit = 1000000}) {
    final b = Budget(
      dbCategory: category,
      limitAmount: limit,
      currencyCode: 'UZS',
      month: 11,
      year: 2026,
      spent: 0,
      remaining: limit,
    );
    db().saveBudget(b);
    return b;
  }

  /// Правка с экрана: новый объект с тем же localId (как в шторке).
  void editAmount(int localId, double amount) {
    final stored = db().getTransaction(localId)!;
    db().saveTransaction(Transaction(
      localId: localId,
      serverId: stored.serverId,
      amount: amount,
      description: stored.description,
      dbCategory: stored.dbCategory,
      dbType: stored.dbType,
      dateMilliseconds: stored.dateMilliseconds,
      dateCreatedMilliseconds: stored.dateCreatedMilliseconds,
      currencyCode: stored.currencyCode,
      isModified: true,
    ));
  }

  List<RequestOptions> syncRequests() =>
      adapter.requests.where((r) => r.path == '/sync/').toList();

  group('SYNC-05: одна очередь синхронизации', () {
    test('два параллельных syncAll не пересекаются по запросам', () async {
      addTransaction();
      adapter.handler = (options) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (options.path == '/sync/') return _acceptAll(options);
        if (options.path == '/transactions/') {
          return _json({
            'status': 'success',
            'data': {'items': [], 'has_more': false},
          });
        }
        return _json({'status': 'success', 'data': []});
      };

      final results = await Future.wait([sync.syncAll(), sync.syncAll()]);

      expect(adapter.maxInFlight, 1);
      // Первый синк: /sync/ + GET транзакций + GET лимитов; второму
      // выгружать уже нечего — только загрузка.
      expect(adapter.requests.map((r) => r.path).toList(), [
        '/sync/',
        '/transactions/',
        '/budgets/',
        '/transactions/',
        '/budgets/',
      ]);
      expect(results, hasLength(2));
    });

    test('ошибка одной задачи не блокирует следующие', () async {
      addTransaction();
      var attempt = 0;
      adapter.handler = (options) async {
        if (attempt++ == 0) {
          throw DioException.connectionError(
              requestOptions: options, reason: 'offline');
        }
        return _acceptAll(options);
      };

      final first = sync.syncLocalDataToBackend();
      final second = sync.syncLocalDataToBackend();

      await expectLater(first, throwsA(isA<SyncException>()));
      await second;
      expect(db().getUnsyncedTransactions(), isEmpty);
    });

    test('правка во время выгрузки не теряется', () async {
      final tx = addTransaction(amount: 100);
      final responded = Completer<void>();
      adapter.handler = (options) async {
        // Пользователь правит сумму, пока запрос в пути.
        editAmount(tx.localId, 250);
        responded.complete();
        return _acceptAll(options);
      };

      await sync.syncLocalDataToBackend();
      await responded.future;

      final stored = db().getTransaction(tx.localId)!;
      final sentId =
          ((syncRequests().single.data as Map)['transactions'] as List)
              .single['id'];
      expect(stored.amount, 250);
      expect(stored.serverId, sentId);
      expect(stored.isModified, isTrue,
          reason: 'правка должна остаться в очереди невыгруженных');

      adapter.handler = (options) async => _acceptAll(options);
      await sync.syncLocalDataToBackend();
      final resent =
          ((syncRequests().last.data as Map)['transactions'] as List).single;
      expect(resent['id'], sentId);
      expect(resent['amount'], 250);
      expect(db().getTransaction(tx.localId)!.isModified, isFalse);
    });

    test('удалённая во время выгрузки операция не возвращается', () async {
      final tx = addTransaction();
      adapter.handler = (options) async {
        db().deleteTransaction(tx.localId);
        return _acceptAll(options);
      };

      await sync.syncLocalDataToBackend();

      expect(db().getTransaction(tx.localId), isNull);
      expect(db().getAllTransactions(), isEmpty);
    });

    test('правка лимита во время выгрузки не теряется', () async {
      final budget = addBudget('food', limit: 1000);
      adapter.handler = (options) async {
        final stored = db().getBudget(budget.localId)!;
        db().saveBudget(Budget(
          localId: stored.localId,
          serverId: stored.serverId,
          dbCategory: stored.dbCategory,
          limitAmount: 2000,
          currencyCode: stored.currencyCode,
          month: stored.month,
          year: stored.year,
          spent: 0,
          remaining: 2000,
          isModified: true,
        ));
        return _acceptAll(options);
      };

      await sync.syncLocalDataToBackend();

      final stored = db().getBudget(budget.localId)!;
      expect(stored.limitAmount, 2000);
      expect(stored.serverId, 'srv-food');
      expect(stored.isModified, isTrue);
    });
  });

  group('SYNC-06: подтверждение только по ID из ответа', () {
    test('пустой synced_transactions ничего не помечает выгруженным', () async {
      final fresh = addTransaction();
      final edited = addTransaction()
        ..serverId = 'already-synced'
        ..isModified = true;
      db().putTransactions([edited]);
      adapter.handler = (options) async => _json({
            'status': 'success',
            'data': {
              'synced_transactions': [],
              'synced_budgets': [],
              'rejected': [],
            },
          });

      await sync.syncLocalDataToBackend();

      expect(db().getTransaction(fresh.localId)!.isModified, isTrue);
      expect(db().getTransaction(edited.localId)!.isModified, isTrue);
      // Неподтверждённые записи не удаляются сверкой с сервером.
      db().reconcileTransactions([]);
      expect(db().getAllTransactions(), hasLength(2));
    });

    test('ответ в другом порядке не путает ID', () async {
      final a = addTransaction(amount: 1);
      final b = addTransaction(amount: 2);
      final budgetFood = addBudget('food');
      final budgetTaxi = addBudget('transport');
      adapter.handler = (options) async => _acceptAll(options, reversed: true);

      await sync.syncLocalDataToBackend();

      final sent = ((syncRequests().single.data as Map)['transactions'] as List)
          .cast<Map>();
      String sentIdFor(double amount) =>
          sent.firstWhere((t) => t['amount'] == amount)['id'] as String;
      expect(db().getTransaction(a.localId)!.serverId, sentIdFor(1));
      expect(db().getTransaction(b.localId)!.serverId, sentIdFor(2));
      expect(db().getUnsyncedTransactions(), isEmpty);
      expect(db().getBudget(budgetFood.localId)!.serverId, 'srv-food');
      expect(db().getBudget(budgetTaxi.localId)!.serverId, 'srv-transport');
      expect(db().getUnsyncedBudgets(), isEmpty);
    });

    test('лимит получает ID существующей на сервере записи по ключу', () async {
      final budget = addBudget('food');
      adapter.handler = (options) async => _json({
            'status': 'success',
            'data': {
              'synced_transactions': [],
              'synced_budgets': [
                {
                  'id': 'server-existing',
                  'category': 'food',
                  'month': 11,
                  'year': 2026,
                  'limit_amount': 1000000,
                },
              ],
              'rejected': [],
            },
          });

      await sync.syncLocalDataToBackend();

      final stored = db().getBudget(budget.localId)!;
      expect(stored.serverId, 'server-existing');
      expect(stored.isModified, isFalse);
    });
  });

  group('NEW-4: выгрузка частями', () {
    test('501 операция уходит батчами не больше лимита', () async {
      db().putTransactions([for (var i = 0; i < 501; i++) newTransaction()]);

      await sync.syncLocalDataToBackend();

      final sizes = syncRequests()
          .map((r) => ((r.data as Map)['transactions'] as List).length)
          .toList();
      expect(sizes, [200, 200, 101]);
      expect(sizes.every((n) => n <= SyncService.syncBatchSize), isTrue);
      expect(db().getUnsyncedTransactions(), isEmpty);
    });

    test('сбой второго батча сохраняет результат первого', () async {
      db().putTransactions([for (var i = 0; i < 250; i++) newTransaction()]);
      var call = 0;
      adapter.handler = (options) async {
        if (call++ == 1) return _json({'detail': 'boom'}, 500);
        return _acceptAll(options);
      };

      await expectLater(
          sync.syncLocalDataToBackend(), throwsA(isA<SyncException>()));

      expect(db().getUnsyncedTransactions(), hasLength(50));
    });

    test('удаление лимита не попадает в budgets без категории', () async {
      await PendingDeletionsStore.instance.addBudget('budget-to-delete');

      await sync.syncLocalDataToBackend();

      final payload = syncRequests().single.data as Map;
      expect(payload['budgets'], isEmpty);
      expect(payload['deleted_budget_ids'], ['budget-to-delete']);
      expect(PendingDeletionsStore.instance.budgetIds, isEmpty);
    });

    test('ответ /sync/ не той формы не очищает очередь удалений', () async {
      await PendingDeletionsStore.instance.addTransaction('tx-to-delete');
      adapter.handler = (options) async => _json({'status': 'success'});

      await expectLater(
          sync.syncLocalDataToBackend(), throwsA(isA<SyncException>()));

      expect(PendingDeletionsStore.instance.transactionIds, {'tx-to-delete'});
    });
  });

  group('NEW-5/NEW-6: ETag и форма ответа загрузки', () {
    ResponseBody transactionsPage(List<Map<String, dynamic>> items,
            [String? etag]) =>
        _json({
          'status': 'success',
          'data': {'items': items, 'has_more': false},
        }, 200, etag);

    test('GET транзакций 200 → GET лимитов упал → повтор без If-None-Match',
        () async {
      final synced = addTransaction()
        ..serverId = 'srv-1'
        ..isModified = false;
      db().putTransactions([synced]);
      final remote = [
        {...synced.toJson(), 'created_at': synced.toJson()['date']},
      ];

      var budgetsFail = true;
      adapter.handler = (options) async {
        if (options.path == '/transactions/') {
          return transactionsPage(remote, '"t-etag"');
        }
        if (budgetsFail) return _json({'detail': 'boom'}, 500);
        return _json({'status': 'success', 'data': []}, 200, '"b-etag"');
      };

      await expectLater(
          sync.syncBackendDataToLocal(), throwsA(isA<SyncException>()));
      expect(sync.transactionsEtag, isNull);

      budgetsFail = false;
      await sync.syncBackendDataToLocal();
      final retried =
          adapter.requests.where((r) => r.path == '/transactions/').toList()[1];
      expect(retried.headers.containsKey('If-None-Match'), isFalse);
      expect(sync.transactionsEtag, '"t-etag"');

      await sync.syncBackendDataToLocal();
      final third =
          adapter.requests.where((r) => r.path == '/transactions/').last;
      expect(third.headers['If-None-Match'], '"t-etag"');
    });

    test('200 без items — ошибка, а не пустой список', () async {
      final synced = addTransaction()
        ..serverId = 'srv-1'
        ..isModified = false;
      db().putTransactions([synced]);
      adapter.handler = (options) async {
        if (options.path == '/transactions/') {
          return _json({
            'status': 'success',
            'data': {'unexpected': true},
          }, 200, '"t-etag"');
        }
        return _json({'status': 'success', 'data': []});
      };

      await expectLater(
          sync.syncBackendDataToLocal(), throwsA(isA<SyncException>()));

      expect(db().getAllTransactions(), hasLength(1));
      expect(sync.transactionsEtag, isNull);
    });

    test('лимиты: 200 без списка — ошибка, лимиты не удаляются', () async {
      final budget = addBudget('food')
        ..serverId = 'srv-food'
        ..isModified = false;
      db().putBudgets([budget]);
      adapter.handler = (options) async {
        if (options.path == '/transactions/') return transactionsPage([]);
        return _json({'status': 'success', 'data': null});
      };

      await expectLater(
          sync.syncBackendDataToLocal(), throwsA(isA<SyncException>()));

      expect(db().getAllBudgets(), hasLength(1));
    });
  });

  group('NEW-7: отклонённые сервером записи', () {
    test('конфликт ID — операция уходит повторно с новым UUID', () async {
      final tx = addTransaction();
      adapter.handler = (options) async {
        final sent =
            ((options.data as Map)['transactions'] as List).single as Map;
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [],
            'synced_budgets': [],
            'rejected': [
              {
                'id': sent['id'],
                'reason':
                    'Идентификатор транзакции отклонен (конфликт идентификатора)',
              },
            ],
          },
        });
      };

      final result = await sync.syncLocalDataToBackend();
      final firstId =
          ((syncRequests().single.data as Map)['transactions'] as List)
              .single['id'];

      expect(result['rejected'], hasLength(1));
      final stored = db().getTransaction(tx.localId)!;
      expect(stored.serverId, isNot(firstId));
      expect(stored.isModified, isTrue);

      adapter.handler = (options) async => _acceptAll(options);
      await sync.syncLocalDataToBackend();
      final secondId =
          ((syncRequests().last.data as Map)['transactions'] as List)
              .single['id'];
      expect(secondId, stored.serverId);
      expect(db().getUnsyncedTransactions(), isEmpty);
    });

    test('прочие отказы оставляют запись в очереди с тем же ID', () async {
      final tx = addTransaction();
      adapter.handler = (options) async {
        final sent =
            ((options.data as Map)['transactions'] as List).single as Map;
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [],
            'synced_budgets': [],
            'rejected': [
              {'id': sent['id'], 'reason': 'Курсы валют недоступны'},
            ],
          },
        });
      };

      await sync.syncLocalDataToBackend();
      final sentId =
          ((syncRequests().single.data as Map)['transactions'] as List)
              .single['id'];

      final stored = db().getTransaction(tx.localId)!;
      expect(stored.serverId, sentId);
      expect(stored.isModified, isTrue);
    });
  });

  group('Счётчик неотправленного в Профиле', () {
    test('растёт при добавлении и обнуляется после подтверждения сервера',
        () async {
      final cubit = ProfileCubit(api: _MockApiService());
      addTearDown(cubit.close);
      expect(cubit.state.pendingSyncCount, 0);

      addTransaction();
      addBudget('food');
      expect(cubit.state.pendingSyncCount, 2);

      await sync.syncLocalDataToBackend();
      expect(cubit.state.pendingSyncCount, 0);
    });

    test('правка во время выгрузки остаётся в счётчике', () async {
      final cubit = ProfileCubit(api: _MockApiService());
      addTearDown(cubit.close);
      final tx = addTransaction(amount: 100);
      adapter.handler = (options) async {
        editAmount(tx.localId, 250);
        return _acceptAll(options);
      };

      await sync.syncLocalDataToBackend();

      expect(cubit.state.pendingSyncCount, 1);
    });

    test('учитывает удаления, ждущие отправки', () async {
      final cubit = ProfileCubit(api: _MockApiService());
      addTearDown(cubit.close);

      await PendingDeletionsStore.instance.addTransaction('srv-deleted');
      expect(cubit.state.pendingSyncCount, 1);

      await sync.syncLocalDataToBackend();
      expect(cubit.state.pendingSyncCount, 0);
    });
  });
}
