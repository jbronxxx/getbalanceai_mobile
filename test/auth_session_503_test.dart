import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ответ бэкенда, когда отзыв токена не записан в Redis: выход/удаление не выполнены.
ResponseBody _serviceUnavailable() => ResponseBody.fromString(
      jsonEncode({
        'status': 'error',
        'code': 'SERVICE_UNAVAILABLE',
        'message': 'Не удалось завершить выход, повторите попытку позже',
      }),
      503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorage storage;
  late Dio dio;
  late AuthApiService authService;
  late List<RequestOptions> requests;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();

    storage = const FlutterSecureStorage();
    requests = [];
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
    dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
      requests.add(options);
      return _serviceUnavailable();
    });
    authService = AuthApiService(dio: dio, storage: storage);
    await authService.setTokens('access-token', 'refresh-token');
  });

  tearDown(() {
    authService.dispose();
  });

  group('Выход из аккаунта при 503 SERVICE_UNAVAILABLE', () {
    test('logout пробрасывает 503 и всё равно очищает токены на устройстве',
        () async {
      await expectLater(
        authService.logout(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', equals(503))),
      );

      expect(requests.single.path, contains('/auth/logout'));
      expect(requests.single.headers['Authorization'],
          equals('Bearer access-token'));
      expect(authService.token, isNull);
      expect(authService.refreshToken, isNull);
      expect(authService.isAuthenticated, isFalse);
      expect(await storage.read(key: 'auth_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
    });
  });

  group('Удаление аккаунта при 503 SERVICE_UNAVAILABLE', () {
    test('deleteAccount пробрасывает 503 и сохраняет сессию', () async {
      final authEvents = <bool>[];
      final subscription = authService.authStream.listen(authEvents.add);

      await expectLater(
        authService.deleteAccount(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', equals(503))),
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(requests.single.method, equals('DELETE'));
      expect(requests.single.path, contains('/auth/me'));
      expect(authService.token, equals('access-token'));
      expect(authService.refreshToken, equals('refresh-token'));
      expect(await storage.read(key: 'auth_token'), equals('access-token'));
      expect(await storage.read(key: 'refresh_token'), equals('refresh-token'));
      expect(authEvents, isEmpty);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;
  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);

  @override
  void close({bool force = false}) {}
}
