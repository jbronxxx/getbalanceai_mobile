import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/budget_api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/pending_deletions_store.dart';
import 'package:getbalanceai_mobile/services/transaction_api_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

/// Экран держит объект, прочитанный до фоновой выгрузки: у него ещё нет
/// `serverId`, хотя в базе выгрузка его уже проставила. Правка и удаление
/// такого объекта не должны терять связь с серверной записью.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});

    final tempDir = await Directory.systemTemp.createTemp('stale_sync_ids');
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

  setUp(() async {
    await LocalDbService.instance.clearAllData();
    await PendingDeletionsStore.instance.clear();
  });

  Transaction newTransaction({double amount = 50000}) => Transaction(
        amount: amount,
        description: 'Обед',
        dbCategory: 'food',
        dbType: 'expense',
        dateMilliseconds: DateTime(2026, 11, 4, 13).millisecondsSinceEpoch,
        dateCreatedMilliseconds:
            DateTime(2026, 11, 4, 13).millisecondsSinceEpoch,
        currencyCode: 'UZS',
      );

  /// Как `SyncService._assignClientTransactionIds`: UUID пишется в базу,
  /// экран об этом не узнаёт.
  void assignServerIdInBackground(int localId, String serverId) {
    final stored = LocalDbService.instance.getTransaction(localId)!;
    stored
      ..serverId = serverId
      ..isModified = true;
    LocalDbService.instance.putTransactions([stored]);
  }

  /// Как правка в `AddTransactionSheet`: новый объект из устаревшего.
  Transaction editedFrom(Transaction stale, {required double amount}) =>
      Transaction(
        localId: stale.localId,
        serverId: stale.serverId,
        amount: amount,
        description: stale.description,
        dbCategory: stale.dbCategory,
        dbType: stale.dbType,
        dateMilliseconds: stale.dateMilliseconds,
        dateCreatedMilliseconds: stale.dateCreatedMilliseconds,
        currencyCode: stale.currencyCode,
        isModified: stale.serverId != null,
      );

  group('Правка устаревшей транзакции', () {
    test('сохраняет присвоенный выгрузкой serverId и ставит в очередь', () {
      final db = LocalDbService.instance;
      final created = newTransaction();
      db.saveTransaction(created);
      final stale = db.getTransaction(created.localId)!;

      assignServerIdInBackground(created.localId, 'uuid-1');
      db.saveTransaction(editedFrom(stale, amount: 60000));

      final stored = db.getTransaction(created.localId)!;
      expect(stored.serverId, 'uuid-1');
      expect(stored.isModified, isTrue);
      expect(stored.amount, 60000);
      expect(db.transactionsCount, 1);
      expect(db.getUnsyncedTransactions().map((t) => t.serverId), ['uuid-1']);
    });

    test('без выгрузки остаётся новой записью без serverId', () {
      final db = LocalDbService.instance;
      final created = newTransaction();
      db.saveTransaction(created);
      final stale = db.getTransaction(created.localId)!;

      db.saveTransaction(editedFrom(stale, amount: 60000));

      final stored = db.getTransaction(created.localId)!;
      expect(stored.serverId, isNull);
      expect(stored.isModified, isFalse);
      expect(stored.amount, 60000);
    });

    test('новая транзакция не наследует чужой serverId', () {
      final db = LocalDbService.instance;
      final first = newTransaction();
      db.saveTransaction(first);
      assignServerIdInBackground(first.localId, 'uuid-1');

      final second = newTransaction(amount: 1000);
      db.saveTransaction(second);

      expect(db.getTransaction(second.localId)!.serverId, isNull);
      expect(db.transactionsCount, 2);
    });
  });

  group('Удаление устаревшей транзакции', () {
    late TransactionApiService api;

    setUp(() {
      api = TransactionApiService(
        dio: Dio(),
        authOptions: ([token]) => Options(),
        isAuthenticated: () => false,
      );
    });

    test('ставит отметку удаления по serverId из базы', () async {
      final db = LocalDbService.instance;
      final created = newTransaction();
      db.saveTransaction(created);
      final stale = db.getTransaction(created.localId)!;
      assignServerIdInBackground(created.localId, 'uuid-1');

      await api.deleteTransactionEverywhere(stale);

      expect(db.getTransaction(created.localId), isNull);
      expect(PendingDeletionsStore.instance.transactionIds, {'uuid-1'});
    });

    test('невыгруженная запись удаляется только локально', () async {
      final db = LocalDbService.instance;
      final created = newTransaction();
      db.saveTransaction(created);

      await api.deleteTransactionEverywhere(created);

      expect(db.getTransaction(created.localId), isNull);
      expect(PendingDeletionsStore.instance.isEmpty, isTrue);
    });
  });

  group('Устаревший лимит бюджета', () {
    Budget newBudget({double limit = 1000000}) => Budget(
          dbCategory: 'food',
          limitAmount: limit,
          currencyCode: 'UZS',
          month: 11,
          year: 2026,
          spent: 0,
          remaining: limit,
        );

    void assignBudgetServerId(int localId, String serverId) {
      final stored = LocalDbService.instance.getBudget(localId)!;
      stored
        ..serverId = serverId
        ..isModified = false;
      LocalDbService.instance.putBudgets([stored]);
    }

    test('правка сохраняет serverId и ставит лимит в очередь', () {
      final db = LocalDbService.instance;
      final created = newBudget();
      db.saveBudget(created);
      final stale = db.getBudget(created.localId)!;
      assignBudgetServerId(created.localId, 'budget-1');

      db.saveBudget(Budget(
        localId: stale.localId,
        serverId: stale.serverId,
        dbCategory: stale.dbCategory,
        limitAmount: 2000000,
        currencyCode: stale.currencyCode,
        month: stale.month,
        year: stale.year,
        spent: 0,
        remaining: 2000000,
        isModified: stale.serverId != null,
      ));

      final stored = db.getBudget(created.localId)!;
      expect(stored.serverId, 'budget-1');
      expect(stored.isModified, isTrue);
      expect(stored.limitAmount, 2000000);
      expect(db.budgetsCount, 1);
    });

    test('удаление ставит отметку по serverId из базы', () async {
      final db = LocalDbService.instance;
      final created = newBudget();
      db.saveBudget(created);
      final stale = db.getBudget(created.localId)!;
      assignBudgetServerId(created.localId, 'budget-1');

      final api = BudgetApiService(
        dio: Dio(),
        authOptions: ([token]) => Options(),
        isAuthenticated: () => false,
      );
      await api.deleteBudgetEverywhere(stale);

      expect(db.getBudget(created.localId), isNull);
      expect(PendingDeletionsStore.instance.budgetIds, {'budget-1'});
    });
  });
}
