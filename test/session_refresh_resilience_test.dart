import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/api_config.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/config/environment.dart';

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

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  final Map<String, String> secureStorage = {};

  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
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
        if (call.method == 'deleteAll') secureStorage.clear();
        return null;
      },
    );
  });

  setUp(() async {
    secureStorage.clear();
    await ApiService.instance.init();
    await ApiService.instance.auth.setTokens('expired_access', 'refresh');
  });

  group('Сессия при сбое обновления токена', () {
    /// Защищённый запрос получает 401, а `/auth/refresh` отвечает [status].
    Future<bool> sessionExpiredAfterRefresh(int status) async {
      final api = ApiService.instance;
      var expired = false;
      final sub = api.authStream.listen((authenticated) {
        if (!authenticated) expired = true;
      });

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == ApiConfig.refreshToken) {
          return _json(
              {'status': 'error', 'code': 'X', 'message': 'x'}, status);
        }
        return _json({'status': 'error', 'code': 'INVALID_TOKEN'}, 401);
      });

      await expectLater(api.getInsights(), throwsA(isA<DioException>()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      return expired;
    }

    for (final status in [429, 500, 503]) {
      test('ответ $status на refresh не завершает сессию', () async {
        expect(await sessionExpiredAfterRefresh(status), isFalse);
        expect(ApiService.instance.isAuthenticated, isTrue);
        expect(secureStorage['refresh_token'], 'refresh');
      });
    }

    test('ответ 401 на refresh завершает сессию', () async {
      expect(await sessionExpiredAfterRefresh(401), isTrue);
      expect(ApiService.instance.isAuthenticated, isFalse);
    });

    test('503 на обычном запросе не вызывает refresh и не завершает сессию',
        () async {
      final api = ApiService.instance;
      var refreshCalls = 0;
      var expired = false;
      final sub = api.authStream.listen((authenticated) {
        if (!authenticated) expired = true;
      });

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == ApiConfig.refreshToken) refreshCalls++;
        return _json({
          'status': 'error',
          'code': 'SERVICE_UNAVAILABLE',
          'message': 'Сервис временно недоступен',
        }, 503);
      });

      await expectLater(api.getInsights(), throwsA(isA<DioException>()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(refreshCalls, 0);
      expect(expired, isFalse);
      expect(api.isAuthenticated, isTrue);
    });
  });

  group('Часовой пояс клиента', () {
    test('запросы к API несут X-Timezone-Offset в минутах от UTC', () async {
      final api = ApiService.instance;
      String? header;

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        header = options.headers['X-Timezone-Offset'] as String?;
        return _json({'status': 'success', 'data': []}, 200);
      });

      await api.dio.get(ApiConfig.budgets);

      expect(header, DateTime.now().timeZoneOffset.inMinutes.toString());
    });

    test('на чужой хост заголовок не отправляется', () async {
      final api = ApiService.instance;
      var sent = true;

      api.dio.httpClientAdapter = _MockDioAdapter((options) {
        sent = options.headers.containsKey('X-Timezone-Offset');
        return ResponseBody.fromString('', 200);
      });

      await api.dio.get('https://lh3.googleusercontent.com/avatar.png');

      expect(sent, isFalse);
    });
  });
}
