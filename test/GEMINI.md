# Правила тестов (test/)

* Стек: `flutter_test`, `bloc_test` (`blocTest` с `build/act/expect/verify`), `mocktail` (без build_runner). Без реальной сети и БД — только моки/in-memory.
* Тесты независимы; синглтоны/глобальное состояние сбрасываются в `setUp`/`tearDown`.
* Покрытие: happy path; нет сети, таймаут Dio, 400/401(refresh)/403/404; 429 с `Retry-After`; 503; `parseAmount` (int, double, string, мусор, null).
* Тесты с сервисами (`AuthApiService`, `EnvironmentConfig`, `PreferencesService`, `AppInfoService`) — иначе зависание на каналах:
  ```dart
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(appName: 'FinanceApp', packageName: 'com.finance.app',
      version: '1.0.0', buildNumber: '1', buildSignature: '');
  LanguageManager.initFallback();
  ```
* `SnackBar`: не `pumpAndSettle()`, а `await tester.pump(); await tester.pump(const Duration(milliseconds: 500));`.
* Запрещены фиктивные ассерты (`expect(true, isTrue)`) и закомментированные падающие тесты.
* Агент тесты не запускает; в конце выдаёт команду `fvm flutter test [test/file_test.dart]`.
