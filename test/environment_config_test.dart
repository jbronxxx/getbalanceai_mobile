import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvironmentConfig.clearListenersForTesting();
    EnvironmentConfig.setDefinesForTesting({
      'PROD_API_BASE_URL': 'https://prod.example.com/api/v1',
      'DEV_API_BASE_URL': 'https://dev.example.com/api/v1',
      'API_BASE_URL': 'http://localhost:8000/api/v1',
    });
  });

  tearDown(() {
    EnvironmentConfig.clearListenersForTesting();
    EnvironmentConfig.setDefinesForTesting(null);
  });

  group('EnvironmentConfig', () {
    test('init defaults to Environment.dev when no preference is saved',
        () async {
      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'https://dev.example.com/api/v1');
    });

    test('init restores saved environment from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'selected_environment': 'local',
      });

      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://localhost:8000/api/v1');
    });

    test(
        'setEnvironment updates current, persists to prefs, and notifies listeners',
        () async {
      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.dev);

      Environment? notifiedEnv;
      EnvironmentConfig.addEnvironmentListener((env) async {
        notifiedEnv = env;
      });

      await EnvironmentConfig.setEnvironment(Environment.local);

      expect(EnvironmentConfig.current, Environment.local);
      expect(notifiedEnv, Environment.local);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_environment'), 'local');
    });

    test('removeEnvironmentListener unregisters listener', () async {
      int callCount = 0;
      Future<void> listener(Environment env) async {
        callCount++;
      }

      EnvironmentConfig.addEnvironmentListener(listener);
      await EnvironmentConfig.setEnvironment(Environment.local);
      expect(callCount, 1);

      EnvironmentConfig.removeEnvironmentListener(listener);
      await EnvironmentConfig.setEnvironment(Environment.dev);
      expect(callCount, 1);
    });

    test(
        'baseUrl falls back to API_BASE_URL for dev when DEV_API_BASE_URL is empty',
        () async {
      EnvironmentConfig.setDefinesForTesting(
          {'API_BASE_URL': 'http://localhost:8000/api/v1'});
      await EnvironmentConfig.setEnvironment(Environment.dev);

      expect(EnvironmentConfig.baseUrl, 'http://localhost:8000/api/v1');
    });

    test('baseUrl falls back to defaultLocalUrl when nothing is defined',
        () async {
      EnvironmentConfig.setDefinesForTesting({});
      await EnvironmentConfig.setEnvironment(Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');

      await EnvironmentConfig.setEnvironment(Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');
    });

    test('init defaults to Environment.dev when nothing is defined', () async {
      EnvironmentConfig.setDefinesForTesting({});

      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');
    });

    test('init respects DEFAULT_ENVIRONMENT define', () async {
      EnvironmentConfig.setDefinesForTesting({
        'DEFAULT_ENVIRONMENT': 'local',
        'API_BASE_URL': 'http://localhost:8000/api/v1',
      });

      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://localhost:8000/api/v1');
    });

    test('switching between environments resolves URLs from defines', () async {
      EnvironmentConfig.setDefinesForTesting({
        'PROD_API_BASE_URL': 'https://api.getbalanceai.app/api/v1',
        'DEV_API_BASE_URL': 'http://192.168.203.61:8000/api/v1',
        'API_BASE_URL': 'http://192.168.1.93:8000/api/v1',
      });
      await EnvironmentConfig.setEnvironment(Environment.prod);
      expect(EnvironmentConfig.baseUrl, 'https://api.getbalanceai.app/api/v1');

      await EnvironmentConfig.setEnvironment(Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'http://192.168.203.61:8000/api/v1');

      await EnvironmentConfig.setEnvironment(Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://192.168.1.93:8000/api/v1');
    });
  });

  group('EnvironmentConfig без PROD_API_BASE_URL', () {
    setUp(() {
      EnvironmentConfig.setDefinesForTesting({
        'DEV_API_BASE_URL': 'https://dev.example.com/api/v1',
      });
    });

    test('prod считается ненастроенным, dev и local — настроенными', () {
      expect(EnvironmentConfig.isConfigured(Environment.prod), isFalse);
      expect(EnvironmentConfig.isConfigured(Environment.dev), isTrue);
      expect(EnvironmentConfig.isConfigured(Environment.local), isTrue);
    });

    test('baseUrl для prod — ошибка, а не пустая строка', () {
      EnvironmentConfig.setCurrentForTesting(Environment.prod);
      expect(() => EnvironmentConfig.baseUrl, throwsStateError);
    });

    test('prod без https — ошибка', () {
      EnvironmentConfig.setDefinesForTesting(
          {'PROD_API_BASE_URL': 'http://api.example.com/api/v1'});
      EnvironmentConfig.setCurrentForTesting(Environment.prod);
      expect(() => EnvironmentConfig.baseUrl, throwsStateError);
    });

    test('сохранённый prod при запуске без define → окружение по умолчанию',
        () async {
      SharedPreferences.setMockInitialValues({'selected_environment': 'prod'});

      await EnvironmentConfig.init();

      expect(EnvironmentConfig.current, Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'https://dev.example.com/api/v1');
    });
  });
}
