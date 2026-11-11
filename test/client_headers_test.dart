import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OBS-02: заголовки о клиенте — версия приложения, ОС, модель, язык —
/// уходят с каждым запросом к бэкенду (журнал запросов сервера), но не на
/// чужие хосты (курсы валют).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessenger messenger() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> androidDevice(Map<String, Object?> info) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger().setMockMethodCallHandler(
      DeviceCapabilityService.channel,
      (call) async => call.method == 'deviceInfo' ? info : null,
    );
    await DeviceCapabilityService.instance.init();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    AppInfoService.instance.setMockPackageInfo(PackageInfo(
      appName: 'GetBalance',
      packageName: 'com.getbalanceai.mobile',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    ));
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger().setMockMethodCallHandler(DeviceCapabilityService.channel, null);
    DeviceCapabilityService.instance.reset();
    AppInfoService.instance.reset();
  });

  group('AppInfoService.clientHeaders', () {
    test('Android: версия, ОС с уровнем API, модель, язык', () async {
      await androidDevice({
        'sdkInt': 35,
        'release': '15',
        'manufacturer': 'samsung',
        'model': 'SM-S921B',
      });

      expect(AppInfoService.instance.clientHeaders, {
        'X-App-Version': '1.2.3+42',
        'X-Platform': 'Android 15; API 35',
        'X-Device-Model': 'samsung SM-S921B',
        'X-App-Language': 'ru',
      });
    });

    test('язык берётся на момент запроса', () async {
      await androidDevice({'sdkInt': 35, 'release': '15'});
      LanguageManager.setLanguage(AppLanguage.en, save: false);

      expect(AppInfoService.instance.clientHeaders['X-App-Language'], 'en');
    });

    test('без данных устройства — без модели, платформа без версии', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final headers = AppInfoService.instance.clientHeaders;
      expect(headers['X-Platform'], 'Android');
      expect(headers.containsKey('X-Device-Model'), isFalse);
    });

    test('до загрузки PackageInfo версия не отправляется', () {
      AppInfoService.instance.reset();

      expect(
        AppInfoService.instance.clientHeaders.containsKey('X-App-Version'),
        isFalse,
      );
    });

    test('не на Android — имя платформы', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(AppInfoService.instance.clientHeaders['X-Platform'], 'iOS');
    });

    test('значение — печатный ASCII не длиннее 64 символов', () async {
      await androidDevice({
        'manufacturer': 'Мегафон',
        'model': 'X' * 100,
      });

      final model = AppInfoService.instance.clientHeaders['X-Device-Model']!;
      expect(model, startsWith('??????? X'));
      expect(model.length, 64);
      expect(RegExp(r'^[\x20-\x7E]+$').hasMatch(model), isTrue);
    });
  });

  group('ApiService отправляет заголовки о клиенте', () {
    late HttpClientAdapter originalAdapter;
    late List<RequestOptions> requests;

    setUp(() async {
      EnvironmentConfig.setDefinesForTesting(
          {'API_BASE_URL': 'http://localhost:8000/api/v1'});
      await androidDevice({
        'sdkInt': 35,
        'release': '15',
        'manufacturer': 'samsung',
        'model': 'SM-S921B',
      });
      requests = [];
      originalAdapter = ApiService.instance.dio.httpClientAdapter;
      ApiService.instance.dio.httpClientAdapter = _Adapter(requests);
    });

    tearDown(() {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('в запросе к бэкенду', () async {
      await ApiService.instance.dio.get('/currencies/rates');

      final headers = requests.single.headers;
      expect(headers['X-App-Version'], '1.2.3+42');
      expect(headers['X-Platform'], 'Android 15; API 35');
      expect(headers['X-Device-Model'], 'samsung SM-S921B');
      expect(headers['X-App-Language'], 'ru');
    });

    test('не на чужой хост', () async {
      await ApiService.instance.dio
          .get('https://open.er-api.com/v6/latest/USD');

      final headers = requests.single.headers;
      for (final name in [
        'X-App-Version',
        'X-Platform',
        'X-Device-Model',
        'X-App-Language',
      ]) {
        expect(headers.containsKey(name), isFalse, reason: name);
      }
    });
  });
}

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests;

  _Adapter(this.requests);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
