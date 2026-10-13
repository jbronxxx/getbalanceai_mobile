import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvironmentConfig.clearListenersForTesting();
    dotenv.testLoad(fileInput: '''
PROD_API_BASE_URL=https://prod.example.com/api/v1
DEV_API_BASE_URL=https://dev.example.com/api/v1
API_BASE_URL=http://localhost:8000/api/v1
''');
  });

  tearDown(() {
    EnvironmentConfig.clearListenersForTesting();
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
      dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
      await EnvironmentConfig.setEnvironment(Environment.dev);

      expect(EnvironmentConfig.baseUrl, 'http://localhost:8000/api/v1');
    });

    test('baseUrl falls back to defaultLocalUrl when dotenv is uninitialized',
        () async {
      dotenv = DotEnv();
      await EnvironmentConfig.setEnvironment(Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');

      await EnvironmentConfig.setEnvironment(Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');
    });

    test(
        'baseUrl falls back to defaultLocalUrl when dotenv has empty configuration',
        () async {
      dotenv.testLoad(fileInput: '');
      await EnvironmentConfig.setEnvironment(Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');

      await EnvironmentConfig.setEnvironment(Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');
    });

    test('init safely defaults to Environment.dev when dotenv is uninitialized',
        () async {
      dotenv = DotEnv();
      SharedPreferences.setMockInitialValues({});

      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.dev);
      expect(EnvironmentConfig.baseUrl, 'http://10.0.2.2:8000/api/v1');
    });

    test('init respects DEFAULT_ENVIRONMENT from dotenv when available',
        () async {
      dotenv.testLoad(fileInput: '''
DEFAULT_ENVIRONMENT=local
API_BASE_URL=http://localhost:8000/api/v1
''');
      SharedPreferences.setMockInitialValues({});

      await EnvironmentConfig.init();
      expect(EnvironmentConfig.current, Environment.local);
      expect(EnvironmentConfig.baseUrl, 'http://localhost:8000/api/v1');
    });
  });
}
