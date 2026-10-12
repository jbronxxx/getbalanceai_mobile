import 'package:getbalanceai_mobile/utils/utils.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:getbalanceai_mobile/main.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/preferences_service.dart';

import 'package:getbalanceai_mobile/widgets/widgets.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // path_provider не имеет платформенной реализации в `flutter test` (нет
    // реального устройства/эмулятора) — подменяем канал временной папкой,
    // чтобы LocalDbService.init() мог открыть ObjectBox.
    final tempDir = await Directory.systemTemp.createTemp('finance_app_test');

    // Мокаем FlutterSecureStorage чтобы тест не зависал
    FlutterSecureStorage.setMockInitialValues({});
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

    // dotenv.testLoad не требует физического .env-файла — подходит для тестов.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
    await LocalDbService.init();
    LanguageManager.initFallback();
  });

  testWidgets('Приложение запускается и показывает нижнюю навигацию',
      (tester) async {
    await ApiService.instance.setTokens('test_token', 'test_refresh');
    await PreferencesService.instance
        .saveLanguage('ru'); // Prevent welcome sheet
    ApiService.instance.dio.httpClientAdapter =
        HttpClientAdapter(); // Clear any existing mock
    // Mock the HTTP adapter to prevent actual network calls that cause test to hang
    ApiService.instance.dio.httpClientAdapter = _MockHttpClientAdapter();
    await tester.pumpWidget(const FinanceApp());
    await tester.pump();

    expect(find.byType(LiquidGlassNavBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiquidGlassNavBar),
        matching: find.text('Баланс'),
      ),
      findsOneWidget,
    );
    expect(find.text('Лимиты'), findsOneWidget);
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status":"success","data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
