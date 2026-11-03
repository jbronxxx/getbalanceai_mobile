import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/sync_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

class _MockDioAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Transaction _newTransaction() => Transaction(
      amount: 42,
      description: 'Кофе',
      dbCategory: 'food',
      dbType: 'expense',
      dateMilliseconds: DateTime.utc(2026, 10, 10).millisecondsSinceEpoch,
      dateCreatedMilliseconds:
          DateTime.utc(2026, 10, 10).millisecondsSinceEpoch,
    );

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  final Map<String, String> secureStorage = {};
  late _MockLocalDbService db;
  late ApiService api;

  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments is Map ? call.arguments['key'] : null;
        if (call.method == 'read') return secureStorage[key];
        if (call.method == 'write') {
          secureStorage[key as String] = call.arguments['value'] as String;
        }
        if (call.method == 'delete') secureStorage.remove(key);
        return null;
      },
    );
  });

  setUp(() async {
    secureStorage.clear();
    db = _MockLocalDbService();
    LocalDbService.instance = db;
    when(() => db.getUnsyncedBudgets()).thenReturn([]);
    when(() => db.putTransactions(any())).thenReturn(null);
    api = ApiService.instance;
    await api.init();
    await api.setTokens('access', 'refresh');
  });

  group('Идемпотентная выгрузка новых транзакций', () {
    test('новая транзакция получает UUID до отправки и уходит с ним в id',
        () async {
      final tx = _newTransaction();
      when(() => db.getUnsyncedTransactions()).thenReturn([tx]);
      Map<String, dynamic>? sentPayload;

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        sentPayload = Map<String, dynamic>.from(options.data as Map);
        final sent = (sentPayload!['transactions'] as List).first as Map;
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [
              {...sent, 'base_amount': 42, 'created_at': sent['date']}
            ],
            'synced_budgets': [],
            'rejected': [],
          },
        }, 200);
      });

      await api.sync.syncLocalDataToBackend();

      final sentId = (sentPayload!['transactions'] as List).first['id'];
      expect(sentId, isA<String>());
      expect(tx.serverId, sentId);
      expect(tx.isModified, isFalse);
    });

    test('при потерянном ответе повтор отправляет тот же id', () async {
      final tx = _newTransaction();
      when(() => db.getUnsyncedTransactions()).thenReturn([tx]);
      final sentIds = <String>[];
      var attempt = 0;

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        attempt++;
        final sent = (options.data['transactions'] as List).first as Map;
        sentIds.add(sent['id'] as String);
        if (attempt == 1) {
          // Сервер записал батч, но ответ до клиента не дошёл
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'connection reset',
          );
        }
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [
              {...sent, 'base_amount': 42, 'created_at': sent['date']}
            ],
            'synced_budgets': [],
            'rejected': [],
          },
        }, 200);
      });

      await expectLater(
          api.sync.syncLocalDataToBackend(), throwsA(isA<SyncException>()));
      // UUID сохранён локально до отправки и запись осталась в очереди
      expect(tx.serverId, isNotNull);
      expect(tx.isModified, isTrue);
      verify(() => db.putTransactions([tx])).called(1);

      await api.sync.syncLocalDataToBackend();

      expect(sentIds, hasLength(2));
      expect(sentIds[1], sentIds[0]);
      expect(tx.isModified, isFalse);
    });

    test('уже выгруженная транзакция сохраняет свой serverId', () async {
      final tx = _newTransaction()
        ..serverId = 'existing-server-id'
        ..isModified = true;
      when(() => db.getUnsyncedTransactions()).thenReturn([tx]);
      String? sentId;

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        final sent = (options.data['transactions'] as List).first as Map;
        sentId = sent['id'] as String;
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [
              {...sent, 'base_amount': 42, 'created_at': sent['date']}
            ],
            'synced_budgets': [],
            'rejected': [],
          },
        }, 200);
      });

      await api.sync.syncLocalDataToBackend();

      expect(sentId, 'existing-server-id');
      expect(tx.serverId, 'existing-server-id');
    });

    test('отклонённая сервером запись остаётся невыгруженной', () async {
      final rejected = _newTransaction();
      final accepted = _newTransaction();
      when(() => db.getUnsyncedTransactions()).thenReturn([rejected, accepted]);

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        final items = (options.data['transactions'] as List).cast<Map>();
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [
              {...items[1], 'base_amount': 42, 'created_at': items[1]['date']}
            ],
            'synced_budgets': [],
            'rejected': [
              {'id': items[0]['id'], 'reason': 'Сумма слишком велика'}
            ],
          },
        }, 200);
      });

      await api.sync.syncLocalDataToBackend();

      expect(rejected.isModified, isTrue);
      expect(accepted.isModified, isFalse);
    });
  });
}
