import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/auto_sync_service.dart';
import 'package:getbalanceai_mobile/services/budget_api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/pending_deletions_store.dart';
import 'package:getbalanceai_mobile/services/transaction_api_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

const _wifi = [ConnectivityResult.wifi];
const _mobile = [ConnectivityResult.mobile];
const _none = [ConnectivityResult.none];

/// Управляемое окружение для [AutoSyncService].
class _Harness {
  _Harness({this.authenticated = true, this.network = _wifi});

  bool authenticated;
  List<ConnectivityResult> network;
  DateTime now = DateTime(2026, 11, 6, 12);
  int syncs = 0;
  int flushes = 0;
  Object? syncError;
  Completer<void>? syncGate;
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  late final service = AutoSyncService(
    sync: () async {
      syncs++;
      await syncGate?.future;
      if (syncError != null) throw syncError!;
    },
    isAuthenticated: () => authenticated,
    flushDeletions: () async => flushes++,
    connectivityChanges: changes.stream,
    checkConnectivity: () async => network,
    clock: () => now,
  );

  /// Сеть сменилась: [network] и событие подписчикам.
  Future<void> setNetwork(WidgetTester tester, List<ConnectivityResult> value) {
    network = value;
    changes.add(value);
    return tester.pump();
  }

  void dispose() {
    service.stop();
    changes.close();
  }
}

/// Переводит приложение по цепочке состояний, как это делает движок.
Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

/// Приложение ушло в фон и вернулось.
Future<void> _backgroundAndReturn(WidgetTester tester) => _lifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

void main() {
  group('AutoSyncService', () {
    late _Harness h;

    Future<void> start(WidgetTester tester, [_Harness? harness]) async {
      h = harness ?? _Harness();
      addTearDown(h.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      h.service.start();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('синк при старте', (tester) async {
      await start(tester);
      expect(h.syncs, 1);
    });

    testWidgets('повторный start не запускает второй синк', (tester) async {
      await start(tester);
      h.service.start();
      await tester.pump();
      expect(h.syncs, 1);
    });

    testWidgets('без входа в аккаунт ничего не делает', (tester) async {
      await start(tester, _Harness(authenticated: false));
      await _backgroundAndReturn(tester);
      await h.setNetwork(tester, _none);
      await h.setNetwork(tester, _wifi);
      await tester.pump(const Duration(seconds: 3));
      expect(h.syncs, 0);
    });

    testWidgets('без сети при старте — синк после её появления с задержкой',
        (tester) async {
      await start(tester, _Harness(network: _none));
      expect(h.syncs, 0);

      await h.setNetwork(tester, _wifi);
      await tester.pump(const Duration(seconds: 1));
      expect(h.syncs, 0, reason: 'ждём networkDebounce');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(h.syncs, 1);
    });

    testWidgets('«дребезг» сети даёт один синк', (tester) async {
      await start(tester);
      await h.setNetwork(tester, _none);
      await h.setNetwork(tester, _wifi);
      await h.setNetwork(tester, _none);
      await h.setNetwork(tester, _mobile);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(h.syncs, 2, reason: 'старт + одно появление сети');
    });

    testWidgets('смена Wi-Fi на мобильную без офлайна — не повод для синка',
        (tester) async {
      await start(tester);
      await h.setNetwork(tester, _mobile);
      await tester.pump(const Duration(seconds: 3));
      expect(h.syncs, 1);
    });

    testWidgets('возврат из фона: не чаще раза в минуту после успеха',
        (tester) async {
      await start(tester);

      h.now = h.now.add(const Duration(seconds: 30));
      await _backgroundAndReturn(tester);
      expect(h.syncs, 1);

      h.now = h.now.add(const Duration(seconds: 31));
      await _backgroundAndReturn(tester);
      await tester.pump();
      expect(h.syncs, 2);
    });

    testWidgets('после неудачного синка возврат синхронизирует сразу',
        (tester) async {
      final harness = _Harness()..syncError = Exception('503');
      await start(tester, harness);
      expect(h.syncs, 1);

      h.syncError = null;
      await _backgroundAndReturn(tester);
      await tester.pump();
      expect(h.syncs, 2);
    });

    testWidgets('триггер во время идущего синка пропускается', (tester) async {
      final harness = _Harness()..syncGate = Completer<void>();
      await start(tester, harness);
      expect(h.syncs, 1);

      await h.setNetwork(tester, _none);
      await h.setNetwork(tester, _wifi);
      await tester.pump(const Duration(seconds: 2));
      expect(h.syncs, 1);

      h.syncGate!.complete();
      await tester.pump();
      expect(h.syncs, 1);
    });

    testWidgets('уход в фон выполняет отложенные удаления', (tester) async {
      await start(tester);
      await _lifecycle(
        tester,
        [AppLifecycleState.inactive, AppLifecycleState.hidden],
      );
      expect(h.flushes, 1);
    });

    testWidgets('после stop события игнорируются', (tester) async {
      await start(tester);
      h.service.stop();
      await _backgroundAndReturn(tester);
      h.now = h.now.add(const Duration(minutes: 5));
      await _backgroundAndReturn(tester);
      expect(h.syncs, 1);
      expect(h.flushes, 0);
    });
  });

  group('Удаление на сервере: «надгробие» до запроса', () {
    late List<String> deleted;
    late bool failDelete;
    late Set<String> tombstonesDuringRequest;

    setUpAll(() async {
      FlutterSecureStorage.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp('auto_sync');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => call.method == 'getApplicationDocumentsDirectory'
            ? tempDir.path
            : null,
      );
      EnvironmentConfig.setDefinesForTesting(
          {'API_BASE_URL': 'http://localhost:8000/api/v1'});
      LanguageManager.initFallback();
      await LocalDbService.init();
    });

    setUp(() async {
      await LocalDbService.instance.clearAllData();
      await PendingDeletionsStore.instance.clear();
      deleted = [];
      failDelete = false;
      tombstonesDuringRequest = {};
    });

    Dio fakeServer() => Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        final store = PendingDeletionsStore.instance;
        tombstonesDuringRequest = {...store.transactionIds, ...store.budgetIds};
        if (failDelete) {
          handler.reject(DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ));
          return;
        }
        deleted.add(options.path);
        handler.resolve(Response(requestOptions: options, statusCode: 204));
      }));

    Transaction syncedTransaction() {
      final t = Transaction(
        amount: 50000,
        description: 'Обед',
        dbCategory: 'food',
        dbType: 'expense',
        dateMilliseconds: DateTime(2026, 11, 6).millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime(2026, 11, 6).millisecondsSinceEpoch,
        currencyCode: 'EUR',
        serverId: 'tx-1',
      );
      LocalDbService.instance.putTransactions([t]);
      return t;
    }

    Budget syncedBudget() {
      final b = Budget(
        dbCategory: 'food',
        limitAmount: 1000000,
        currencyCode: 'EUR',
        month: 11,
        year: 2026,
        spent: 0,
        remaining: 1000000,
        serverId: 'b-1',
      );
      LocalDbService.instance.putBudgets([b]);
      return b;
    }

    TransactionApiService transactions() => TransactionApiService(
          dio: fakeServer(),
          authOptions: ([token]) => Options(),
          isAuthenticated: () => true,
        );

    BudgetApiService budgets() => BudgetApiService(
          dio: fakeServer(),
          authOptions: ([token]) => Options(),
          isAuthenticated: () => true,
        );

    test('операция: отметка есть во время запроса и снята после успеха',
        () async {
      final t = syncedTransaction();

      await transactions().deleteTransactionEverywhere(t);

      expect(tombstonesDuringRequest, contains('tx-1'));
      expect(deleted, hasLength(1));
      expect(PendingDeletionsStore.instance.isEmpty, isTrue);
      expect(LocalDbService.instance.getTransaction(t.localId), isNull);
    });

    test('операция: при ошибке сети отметка остаётся до синка', () async {
      final t = syncedTransaction();
      failDelete = true;

      await transactions().deleteTransactionEverywhere(t);

      expect(PendingDeletionsStore.instance.transactionIds, {'tx-1'});
    });

    test('лимит: отметка есть во время запроса и снята после успеха', () async {
      final b = syncedBudget();

      await budgets().deleteBudgetEverywhere(b);

      expect(tombstonesDuringRequest, contains('b-1'));
      expect(deleted, hasLength(1));
      expect(PendingDeletionsStore.instance.isEmpty, isTrue);
    });

    test('лимит: при ошибке сети отметка остаётся до синка', () async {
      final b = syncedBudget();
      failDelete = true;

      await budgets().deleteBudgetEverywhere(b);

      expect(PendingDeletionsStore.instance.budgetIds, {'b-1'});
    });
  });
}
