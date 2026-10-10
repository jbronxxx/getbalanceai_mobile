# Регламент тестирования (test/GEMINI.md)

Данные правила применяются при написании, рефакторинге и запуске тестов в директории `test/`.

---

## 1. Стек и инфраструктура тестов

* **Фреймворк**: `flutter_test` (входит в Flutter SDK).
* **Тестирование состояний**: `bloc_test` для проверки потоков состояний Cubit (`blocTest`).
* **Мокирование зависимостей**: `mocktail` для создания легковесных моков без необходимости запуска кодогенерации `build_runner`.
* **Тестирование виджетов**: `testWidgets` с `WidgetTester` для проверки корректного рендеринга и реакции на пользовательские взаимодействия.
* **Изоляция сети и БД**: Никаких реальных сетевых вызовов через интернет. Для тестирования `ApiService` и `LocalDbService` используются моки либо фикстуры в памяти.

---

## 2. Стандарты написания тестов

* **Принцип независимости (Isolation)**:
  * Каждый тест должен быть полностью автономен. Запрещено полагаться на порядок выполнения тестов или глобальное состояние.
  * Если используются синглтоны или глобальные настройки, сбрасывать их состояние в `setUp()` / `tearDown()`.
* **Тестирование логики Cubit (`blocTest`)**:
  * Использовать декларативный синтаксис `blocTest`:
    ```dart
    blocTest<InsightsCubit, InsightsState>(
      'успешно загружает инсайты и эмитит loading -> success',
      build: () {
        when(() => mockApiService.getInsights(currency: any(named: 'currency')))
            .thenAnswer((_) async => mockInsightsResponse);
        return InsightsCubit(apiService: mockApiService);
      },
      act: (cubit) => cubit.loadInsights(),
      expect: () => [
        isA<InsightsState>().having((s) => s.status, 'status', InsightsStatus.loading),
        isA<InsightsState>().having((s) => s.status, 'status', InsightsStatus.success),
      ],
      verify: (_) {
        verify(() => mockApiService.getInsights(currency: any(named: 'currency'))).called(1);
      },
    );
    ```
* **Обязательные сценарии покрытия**:
  * **Happy Path**: успешная загрузка, корректная смена статусов и полей состояния.
  * **Сетевые и серверные сбои**: отсутствие сети, таймаут Dio, ошибки HTTP 400, 401 (Refresh), 403, 404.
  * **Системные коды API**: корректная реакция на HTTP 429 (`RATE_LIMIT_EXCEEDED` с парсингом `Retry-After`) и HTTP 503 (`SERVICE_UNAVAILABLE`).
  * **Финансовая арифметика и парсинг**: тестирование хелпера `parseAmount` на всех типах входных данных (int, double, string, некорректные строки, null).

* **Мокирование платформенных плагинов и MethodChannel**:
  * В тестах, взаимодействующих с сервисами (`AuthApiService`, `EnvironmentConfig`, `PreferencesService`, `AppInfoService`), **обязательно** инициализировать моки в `setUp()` или `setUpAll()`, иначе тесты зависают на платформенных каналах:
    ```dart
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'FinanceApp',
      packageName: 'com.finance.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    LanguageManager.initFallback();
    ```
* **Тестирование анимированных всплывающих элементов (`SnackBar`)**:
  * Запрещено использовать `await tester.pumpAndSettle()` сразу после действия, вызывающего появление `SnackBar`, так как таймер SnackBar скрывает его до выполнения проверки `expect()`.
  * Использовать контролируемый шаг анимации:
    ```dart
    await tester.tap(find.text('Action Button'));
    await tester.pump(); // Запуск таймера
    await tester.pump(const Duration(milliseconds: 500)); // Завершение анимации появления
    expect(find.text('Успешно'), findsOneWidget);
    ```

---

## 3. Запреты и ограничения

* Запрещено оставлять пустые или фиктивные ассерты (`expect(true, isTrue)`).
* Запрещено оставлять отладочные `print()` / `debugPrint()` в коде тестов.
* Запрещено коммитить закомментированные падающие тесты.

---

## 4. Команды для пользователя

* **Агент не запускает тесты автоматически перед пушем/коммитом**: запуск тестов выполняется пользователем либо настроенным pre-commit хуком (`.githooks/pre-commit`).
* При добавлении или изменении тестов агент информирует пользователя и предоставляет команду для ручного запуска:

```bash
# Запуск полного набора тестов приложения
fvm flutter test

# Запуск конкретного тестового файла
fvm flutter test test/cubits_test.dart
```
