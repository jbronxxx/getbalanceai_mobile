import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/api_config.dart';
import 'package:getbalanceai_mobile/cubits/profile/profile_cubit.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:getbalanceai_mobile/config/environment.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockConnectivity extends Mock implements Connectivity {}

/// Сервер для [ApiService.instance]: обработчик решает, что ответить, и может
/// придержать ответ, чтобы проверить, что происходит «во время» запроса.
class _FakeAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Access-токен, из которого клиент читает userId (`sub`), как у бэкенда.
String _jwt(String userId) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': userId})}.signature';
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

void main() {
  late Directory tempDir;
  late Directory cacheDir;
  late _FakeAdapter adapter;
  const storage = FlutterSecureStorage();

  /// Операции «на сервере» по пользователям — их отдаёт GET /transactions/.
  final remote = <String, List<Map<String, dynamic>>>{};
  String? currentUser;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});

    tempDir = await Directory.systemTemp.createTemp('logout_isolation');
    cacheDir = await Directory(p(tempDir.path, 'cache')).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        if (call.method == 'getTemporaryDirectory') return cacheDir.path;
        return null;
      },
    );

    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
    LanguageManager.initFallback();
    await LocalDbService.init();
  });

  /// Ответы бэкенда для текущего пользователя [currentUser].
  Future<ResponseBody> server(RequestOptions options) async {
    switch (options.path) {
      case ApiConfig.loginApple:
        // identity_token в тестах — это userId.
        final userId = (options.data as Map)['identity_token'] as String;
        currentUser = userId;
        remote.putIfAbsent(userId, () => []);
        return _json({
          'status': 'success',
          'data': {
            'access_token': _jwt(userId),
            'refresh_token': 'refresh-$userId',
            'user': {'id': userId, 'email': '$userId@test', 'name': userId},
          },
        });
      case ApiConfig.sync:
        final data = options.data as Map;
        final txs = (data['transactions'] as List).cast<Map>();
        remote[currentUser!]!.addAll([
          for (final t in txs)
            {...t.cast<String, dynamic>(), 'created_at': t['date']},
        ]);
        return _json({
          'status': 'success',
          'data': {
            'synced_transactions': [
              for (final t in txs) {...t, 'created_at': t['date']},
            ],
            'synced_budgets': [],
            'rejected': [],
          },
        });
      case ApiConfig.transactions:
        final etag = '"etag-$currentUser"';
        if (options.headers['If-None-Match'] == etag) {
          return ResponseBody.fromString('', 304);
        }
        return _json({
          'status': 'success',
          'data': {'items': remote[currentUser!], 'has_more': false},
        }, 200, etag);
      case ApiConfig.budgets:
        return _json({'status': 'success', 'data': []});
      case ApiConfig.logout:
        return _json({'status': 'success', 'message': 'ok'});
      case ApiConfig.me:
        return _json({'status': 'success', 'message': 'deleted'});
    }
    return _json({'detail': 'not found'}, 404);
  }

  Future<void> login(String userId) =>
      ApiService.instance.loginWithApple(userId);

  var minuteOffset = 0;
  Transaction addTransaction(String description) {
    final t = Transaction(
      amount: 50000,
      description: description,
      dbCategory: 'food',
      dbType: 'expense',
      dateMilliseconds: DateTime(2026, 11, 1)
          .add(Duration(minutes: minuteOffset++))
          .millisecondsSinceEpoch,
      dateCreatedMilliseconds: DateTime(2026, 11, 1).millisecondsSinceEpoch,
      currencyCode: 'UZS',
    );
    LocalDbService.instance.saveTransaction(t);
    return t;
  }

  List<String> localDescriptions() => LocalDbService.instance
      .getAllTransactions()
      .map((t) => t.description)
      .toList();

  Future<List<String>> storedEtagKeys() async =>
      (await storage.readAll()).keys.where((k) => k.contains('etag')).toList();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    remote.clear();
    currentUser = null;
    await ApiService.instance.clearAllUserData();
    // Сбрасывает и владельца данных, который SyncService держит в памяти.
    await ApiService.instance.sync.clearLocalData();
    adapter = _FakeAdapter(server);
    ApiService.instance.dio.httpClientAdapter = adapter;
  });

  group('Выход из аккаунта стирает его данные (SEC-01, SEC-07)', () {
    test('вход A → выход → вход B: записи и ETag A не попадают к B', () async {
      await login('A');
      addTransaction('A: обед');
      await ApiService.instance.syncAll();
      expect(await storedEtagKeys(), isNotEmpty);

      final authEvents = <bool>[];
      final sub = ApiService.instance.authStream.listen(authEvents.add);
      final changedBefore = LocalDbService.transactionsChanged.value;

      await ApiService.instance.logout();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(authEvents, [false]);
      expect(ApiService.instance.isAuthenticated, isFalse);
      expect(localDescriptions(), isEmpty, reason: 'гость не видит данные A');
      expect(LocalDbService.transactionsChanged.value, isNot(changedBefore));
      expect(await storedEtagKeys(), isEmpty);

      // Гость добавил операцию и вошёл как B: к B уходит только она.
      addTransaction('гость: кофе');
      adapter.requests.clear();
      await login('B');
      await ApiService.instance.syncAll();

      final pushed = adapter.requests
          .where((r) => r.path == ApiConfig.sync)
          .expand((r) => ((r.data as Map)['transactions'] as List).cast<Map>())
          .map((t) => t['description'])
          .toList();
      expect(pushed, ['гость: кофе']);
      expect(localDescriptions(), ['гость: кофе']);
    });

    test('A → выход → B → выход → A: у A нет 304 по старому ETag', () async {
      await login('A');
      addTransaction('A: обед');
      await ApiService.instance.syncAll();
      await ApiService.instance.logout();

      await login('B');
      await ApiService.instance.syncAll();
      await ApiService.instance.logout();

      // Локальная запись есть — значит, If-None-Match отправился бы, если бы
      // ETag A пережил выход.
      addTransaction('гость: кофе');
      adapter.requests.clear();
      await login('A');
      await ApiService.instance.syncAll();

      final pull =
          adapter.requests.firstWhere((r) => r.path == ApiConfig.transactions);
      expect(pull.headers.containsKey('If-None-Match'), isFalse);
      expect(localDescriptions(), containsAll(['A: обед', 'гость: кофе']));
    });

    test('ошибка сервера при выходе не мешает локальной очистке', () async {
      await login('A');
      addTransaction('A: обед');
      await ApiService.instance.syncAll();
      await PendingDeletionsStore.instance.addTransaction('srv-x');
      adapter.handler = (options) async => options.path == ApiConfig.logout
          ? _json({'code': 'SERVICE_UNAVAILABLE'}, 503)
          : await server(options);

      await expectLater(
          ApiService.instance.logout(), throwsA(isA<DioException>()));

      expect(ApiService.instance.isAuthenticated, isFalse);
      expect(localDescriptions(), isEmpty);
      expect(PendingDeletionsStore.instance.isEmpty, isTrue);
      expect(await storedEtagKeys(), isEmpty);
    });

    test('синк, начатый до выхода, не возвращает записи в очищенную базу',
        () async {
      await login('A');
      remote['A']!.add({
        ...Transaction(
          serverId: '9b2a0f8e-0000-4000-8000-000000000001',
          amount: 1,
          description: 'A: с сервера',
          dbCategory: 'food',
          dbType: 'expense',
          dateMilliseconds: DateTime(2026, 11, 2).millisecondsSinceEpoch,
          dateCreatedMilliseconds: DateTime(2026, 11, 2).millisecondsSinceEpoch,
          currencyCode: 'UZS',
        ).toJson(),
        'created_at': DateTime(2026, 11, 2).toIso8601String(),
      });

      final release = Completer<void>();
      adapter.handler = (options) async {
        if (options.path == ApiConfig.transactions) await release.future;
        return server(options);
      };

      final pull = ApiService.instance.syncAll();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final logout = ApiService.instance.logout();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      release.complete();

      await pull;
      await logout;
      expect(localDescriptions(), isEmpty);
    });

    test('удаление аккаунта стирает данные; при ошибке — ничего', () async {
      await login('A');
      addTransaction('A: обед');
      await ApiService.instance.syncAll();

      adapter.handler = (options) async => options.path == ApiConfig.me
          ? _json({'code': 'SERVICE_UNAVAILABLE'}, 503)
          : await server(options);
      await expectLater(
          ApiService.instance.deleteAccount(), throwsA(isA<DioException>()));
      expect(ApiService.instance.isAuthenticated, isTrue);
      expect(localDescriptions(), ['A: обед']);

      adapter.handler = server;
      final authEvents = <bool>[];
      final sub = ApiService.instance.authStream.listen(authEvents.add);
      await ApiService.instance.deleteAccount();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(authEvents, [false]);
      expect(ApiService.instance.isAuthenticated, isFalse);
      expect(localDescriptions(), isEmpty);
      expect(await storedEtagKeys(), isEmpty);
    });

    test('выход удаляет выгруженные отчёты из кэша (SEC-05)', () async {
      final report = File(p(cacheDir.path, 'getbalance_report_2026-11.pdf'))
        ..writeAsStringSync('pdf');
      final other = File(p(cacheDir.path, 'other.txt'))
        ..writeAsStringSync('keep');
      await login('A');

      await ApiService.instance.logout();

      expect(report.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });
  });

  group('Память владельца данных на устройстве', () {
    Future<String?> owner() => storage.read(key: 'local_data_owner');

    test('гость входит впервые — его записи переносятся в аккаунт', () async {
      addTransaction('гость: кофе');

      await login('A');

      expect(await owner(), 'A');
      expect(localDescriptions(), ['гость: кофе']);
    });

    test('сессия A истекла без выхода → вход B: данные A стёрты до входа',
        () async {
      await login('A');
      addTransaction('A: не выгружено');
      await ApiService.instance.auth.handleSessionExpired();
      expect(localDescriptions(), ['A: не выгружено'],
          reason: 'истечение сессии само по себе данные не трогает');

      // Экраны узнают о входе B, когда данных A уже нет.
      final seenOnSignIn = <List<String>>[];
      final sub = ApiService.instance.authStream.listen((authenticated) {
        if (authenticated) seenOnSignIn.add(localDescriptions());
      });
      adapter.requests.clear();
      await login('B');
      await ApiService.instance.syncAll();
      await sub.cancel();

      expect(seenOnSignIn, isNotEmpty);
      expect(seenOnSignIn.every((list) => list.isEmpty), isTrue);
      expect(await owner(), 'B');
      expect(remote['B'], isEmpty, reason: 'записи A не ушли в аккаунт B');
      expect(localDescriptions(), isEmpty);
    });

    test('сессия A истекла → снова вход A: данные сохраняются', () async {
      await login('A');
      addTransaction('A: не выгружено');
      await ApiService.instance.auth.handleSessionExpired();

      await login('A');
      await ApiService.instance.syncAll();

      expect(localDescriptions(), ['A: не выгружено']);
      expect(remote['A']!.map((t) => t['description']), ['A: не выгружено']);
    });

    test('явный выход сбрасывает владельца', () async {
      await login('A');
      expect(await owner(), 'A');

      await ApiService.instance.logout();

      expect(await owner(), isNull);
    });

    test('старт приложения записывает владельца для уже вошедших', () async {
      await login('A');
      await storage.delete(key: 'local_data_owner');
      // Как после обновления приложения: владелец не записан, в памяти его нет.
      await ApiService.instance.sync.init();

      await ApiService.instance.init();

      expect(await owner(), 'A');
    });
  });

  group('Выход во время обновления токена (NEW-8)', () {
    test('refresh, завершившийся после выхода, не возвращает сессию', () async {
      await login('A');
      final release = Completer<void>();
      adapter.handler = (options) async {
        if (options.path == ApiConfig.refreshToken) {
          await release.future;
          return _json({
            'status': 'success',
            'data': {
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            },
          });
        }
        return server(options);
      };

      final refresh = ApiService.instance.auth.performTokenRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await ApiService.instance.logout();
      release.complete();

      expect(await refresh, isNull);
      expect(ApiService.instance.isAuthenticated, isFalse);
      expect(await storage.read(key: AuthApiService.sessionStorageKey), isNull);
    });
  });

  group('ProfileCubit.prepareLogout', () {
    late _MockApiService api;
    late _MockConnectivity connectivity;

    setUp(() {
      api = _MockApiService();
      connectivity = _MockConnectivity();
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
    });

    test('нечего выгружать — синк не запускается', () async {
      final cubit = ProfileCubit(api: api, connectivity: connectivity);
      expect(cubit.hasChangesToUpload, isFalse);
      expect(await cubit.prepareLogout(), 0);
      verifyNever(() => api.syncAll());
      await cubit.close();
    });

    test('синк выгрузил всё — предупреждать не о чем', () async {
      final t = addTransaction('A: обед');
      when(() => api.syncAll()).thenAnswer((_) async {
        LocalDbService.instance.putTransactions([
          t
            ..serverId = 'srv-1'
            ..isModified = false,
        ]);
        return {};
      });
      final cubit = ProfileCubit(api: api, connectivity: connectivity);
      expect(cubit.hasChangesToUpload, isTrue);

      expect(await cubit.prepareLogout(), 0);
      verify(() => api.syncAll()).called(1);
      await cubit.close();
    });

    test('без сети — возвращает число невыгруженных изменений', () async {
      addTransaction('A: обед');
      addTransaction('A: ужин');
      await PendingDeletionsStore.instance.addTransaction('srv-x');
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      final cubit = ProfileCubit(api: api, connectivity: connectivity);

      expect(await cubit.prepareLogout(), 3);
      verifyNever(() => api.syncAll());
      await cubit.close();
    });

    test('ошибка синка не пробрасывается', () async {
      addTransaction('A: обед');
      when(() => api.syncAll()).thenThrow(Exception('boom'));
      final cubit = ProfileCubit(api: api, connectivity: connectivity);

      expect(await cubit.prepareLogout(), 1);
      await cubit.close();
    });

    test('отложенное удаление выполняется до подсчёта', () async {
      final t = addTransaction('гость: кофе');
      UndoableDeletions.transactions.schedule(t);
      final cubit = ProfileCubit(api: api, connectivity: connectivity);
      expect(cubit.hasChangesToUpload, isTrue);

      expect(await cubit.prepareLogout(), 0);
      expect(UndoableDeletions.transactions.hasPending, isFalse);
      expect(localDescriptions(), isEmpty);
      verifyNever(() => api.syncAll());
      await cubit.close();
    });
  });
}

String p(String dir, String name) => '$dir${Platform.pathSeparator}$name';
