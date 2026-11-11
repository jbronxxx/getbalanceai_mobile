import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/api_config.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _error(int status, [String code = 'X']) =>
    _json({'status': 'error', 'code': code, 'message': 'x'}, status);

ResponseBody _tokens(String access, String refresh) => _json({
      'status': 'success',
      'data': {'access_token': access, 'refresh_token': refresh},
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  setUpAll(() async {
    // Тексты в проверках — русские; язык по умолчанию — английский
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
    final tempDir = await Directory.systemTemp.createTemp('refresh_robustness');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
    await LocalDbService.init();
  });

  group('Пара токенов в хранилище', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    AuthApiService service() => AuthApiService(dio: Dio(), storage: storage);

    test('access и refresh пишутся одним ключом и читаются при запуске',
        () async {
      await service().setTokens('access', 'refresh');

      final restored = service();
      await restored.init();

      expect(restored.token, 'access');
      expect(restored.refreshToken, 'refresh');
      expect(
          (await storage.readAll()).keys, [AuthApiService.sessionStorageKey]);
    });

    test('токены из прежних двух ключей переносятся в один', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'auth_token': 'old-access', 'refresh_token': 'old-refresh'});

      final migrated = service();
      await migrated.init();

      expect(migrated.token, 'old-access');
      expect(migrated.refreshToken, 'old-refresh');
      expect(
          (await storage.readAll()).keys, [AuthApiService.sessionStorageKey]);
    });

    test('выход удаляет и прежние ключи: сессия не воскресает', () async {
      FlutterSecureStorage.setMockInitialValues({
        AuthApiService.sessionStorageKey:
            jsonEncode({'access_token': 'a', 'refresh_token': 'r'}),
        'auth_token': 'stale-access',
        'refresh_token': 'stale-refresh',
      });
      final auth = service();
      await auth.init();

      await auth.clearAllUserData();

      final restarted = service();
      await restarted.init();
      expect(restarted.isAuthenticated, isFalse);
    });
  });

  group('Обновление токена', () {
    late ApiService api;
    late List<String> refreshSent;
    late List<bool> authEvents;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      api = ApiService.instance;
      await api.init();
      await api.auth.setTokens('expired', 'refresh-1');
      refreshSent = [];
      authEvents = [];
      final sub = api.authStream.listen(authEvents.add);
      addTearDown(sub.cancel);
    });

    /// Сервер, где защищённые запросы принимают только access `fresh`, а
    /// ответ на N-й запрос `/auth/refresh` (с нуля) даёт [onRefresh].
    void serve(Future<ResponseBody> Function(RequestOptions, int) onRefresh) {
      api.dio.httpClientAdapter = _Adapter((options) async {
        if (options.path == ApiConfig.refreshToken) {
          refreshSent.add((options.data as Map)['refresh_token'] as String);
          return onRefresh(options, refreshSent.length - 1);
        }
        return options.headers['Authorization'] == 'Bearer fresh'
            ? _json({'status': 'success', 'data': <Object>[]})
            : _error(401, 'INVALID_TOKEN');
      });
    }

    Never lostResponse(RequestOptions options) =>
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 15),
          requestOptions: options,
        );

    test('ответ на refresh потерян — повтор с тем же токеном продолжает сессию',
        () async {
      serve((options, attempt) async =>
          attempt == 0 ? lostResponse(options) : _tokens('fresh', 'refresh-2'));

      final response = await api.dio.get(ApiConfig.budgets);

      expect(response.statusCode, 200);
      expect(refreshSent, ['refresh-1', 'refresh-1']);
      expect(api.auth.refreshToken, 'refresh-2');
      expect(authEvents, isNot(contains(false)));
    });

    test('502 от прокси — тоже повтор', () async {
      serve((options, attempt) async =>
          attempt == 0 ? _error(502) : _tokens('fresh', 'refresh-2'));

      await api.dio.get(ApiConfig.budgets);

      expect(refreshSent, hasLength(2));
      expect(api.auth.refreshToken, 'refresh-2');
    });

    test('повтор не помог — сбой сети вместо «Сессия истекла», сессия цела',
        () async {
      serve((options, _) async => throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ));

      await expectLater(
        api.dio.get(ApiConfig.budgets),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.connectionError)
            .having((e) => e.requestOptions.path, 'path', ApiConfig.budgets)),
      );

      expect(refreshSent, hasLength(2));
      expect(api.isAuthenticated, isTrue);
      expect(api.auth.refreshToken, 'refresh-1');
      expect(authEvents, isNot(contains(false)));
    });

    test('503 на refresh — без повтора, вызывающий получает 503, а не 401',
        () async {
      serve((options, _) async => _error(503, 'SERVICE_UNAVAILABLE'));

      await expectLater(
        api.dio.get(ApiConfig.budgets),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 503)
            .having((e) => e.requestOptions.path, 'path', ApiConfig.budgets)),
      );

      expect(refreshSent, hasLength(1));
      expect(api.isAuthenticated, isTrue);
    });

    test('401 на refresh — без повтора, сессия завершена', () async {
      serve((options, _) async => _error(401, 'TOKEN_REVOKED'));

      await expectLater(
        api.dio.get(ApiConfig.budgets),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );

      expect(refreshSent, hasLength(1));
      expect(api.isAuthenticated, isFalse);
      expect(authEvents, contains(false));
    });
  });

  group('Пагинация синка после обновления токена', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await LocalDbService.instance.clearAllData();
      await ApiService.instance.init();
      await ApiService.instance.auth.setTokens('old', 'refresh-1');
    });

    test('следующие страницы идут с новым токеном без лишних 401', () async {
      final api = ApiService.instance;
      var unauthorized = 0;
      Map<String, Object?> item(String id) => {
            'id': id,
            'amount': 100.0,
            'description': id,
            'category': 'food',
            'type': 'expense',
            'date': '2026-11-01T10:00:00Z',
          };

      api.dio.httpClientAdapter = _Adapter((options) async {
        if (options.path == ApiConfig.refreshToken) {
          return _tokens('new', 'refresh-2');
        }
        final auth = options.headers['Authorization'];
        final cursor = options.queryParameters['cursor'];
        // Токен истёк, пока листались страницы: первую принял старый
        final accepted =
            auth == 'Bearer new' || (auth == 'Bearer old' && cursor == null);
        if (!accepted) {
          unauthorized++;
          return _error(401, 'INVALID_TOKEN');
        }
        if (options.path == ApiConfig.budgets ||
            options.path == ApiConfig.recurringPayments) {
          return _json({'status': 'success', 'data': <Object>[]});
        }
        final page = cursor == null ? 1 : int.parse(cursor as String);
        return _json({
          'status': 'success',
          'data': {
            'transactions': [item('tx-$page')],
            'deleted_transaction_ids': <Object>[],
            'has_more': page < 3,
            'next_cursor': '${page + 1}',
            'server_time': '2026-11-06T10:00:00.000Z',
          },
        });
      });

      final result = await api.sync.syncBackendDataToLocal();

      expect(result['transactions'], 3);
      expect(unauthorized, 1);
    });
  });

  group('Сообщения об ошибках', () {
    DioException dioError(String path, int status) {
      final options = RequestOptions(path: path);
      return DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
      );
    }

    test('429 при синке — текст про лимит, а не «Ошибка синхронизации: 429»',
        () {
      final error = SyncException(
        SyncErrorCode.syncFailed,
        statusCode: 429,
        cause: dioError(ApiConfig.sync, 429),
      );

      expect(AppErrorHandler.getMessage(error), LanguageManager.l10n.http_429);
    });

    Future<void> showError(WidgetTester tester, Object error) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppErrorHandler.show(context, error),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('503 при синке — окно «Сервис недоступен»', (tester) async {
      await showError(
        tester,
        SyncException(
          SyncErrorCode.syncFailed,
          statusCode: 503,
          cause: dioError(ApiConfig.sync, 503),
        ),
      );

      expect(find.text(LanguageManager.l10n.sync_error), findsNothing);
      expect(
          find.text(LanguageManager.l10n.session_expired_title), findsNothing);
      expect(find.text(LanguageManager.l10n.service_unavailable_title),
          findsOneWidget);
    });

    for (final path in [ApiConfig.loginGoogle, ApiConfig.loginApple]) {
      testWidgets('401 на $path — не «Сессия истекла»', (tester) async {
        await showError(tester, dioError(path, 401));

        expect(find.text(LanguageManager.l10n.session_expired_title),
            findsNothing);
      });
    }

    testWidgets('401 на защищённом запросе — «Сессия истекла»', (tester) async {
      await showError(tester, dioError(ApiConfig.budgets, 401));

      expect(find.text(LanguageManager.l10n.session_expired_title),
          findsOneWidget);
    });
  });
}
