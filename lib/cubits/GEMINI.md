# Регламент слоя управления состоянием (lib/cubits/GEMINI.md)

Данные правила применяются при разработке и рефакторинге логики управления состоянием в директории `lib/cubits/`.

---

## 1. Назначение слоя Cubits

Слой Cubit инкапсулирует бизнес-логику пользовательских сценариев, координирует вызовы сетевого сервиса (`ApiService`) и локальной базы данных (`LocalDbService`), управляет потоками данных и формирует иммутабельные состояния для экранов.

### Строгие запреты:
* **Запрещен `BuildContext` внутри Cubit**: Cubit **никогда** не принимает `BuildContext`, не открывает диалоги, не производит навигацию и не вызывает `ScaffoldMessenger`. Все сайд-эффекты передаются в состояние или обрабатываются слушателем (`BlocListener`) на стороне UI.
* **Запрещен прямой мутабельный `emit`**: состояния Cubit должны быть строго иммутабельными (неизменяемыми). Изменение состояния производится созданием нового объекта (метод `copyWith`).
* **Запрещен `emit` после вызова `close()`**: перед каждым асинхронным вызовом `emit()` после `await` обязательна проверка `if (isClosed) return;` во избежание исключения `StateError: Cannot emit new states after calling close`.
* **Категорический запрет `print()` и `debugPrint()`**: логирование бизнес-логики и исключений в кубитах ведется строго через `AppLogger` (`AppLogger.d`, `AppLogger.e`).

---

## 2. Архитектура и структура Cubit

* **Организация файлов фичи**:
  ```
  lib/cubits/<feature>/
  ├── <feature>_cubit.dart   # Логика и методы управления
  └── <feature>_state.dart   # Состояния (part of '<feature>_cubit.dart')
  ```
* **Внедрение зависимостей (Dependency Injection для тестируемости)**:
  * Все внешние сервисы (`ApiService`, `Connectivity`, `LocalDbService`) передаются в конструктор Cubit как опциональные именованные параметры и по умолчанию инициализируются из синглтонов:
    ```dart
    class InsightsCubit extends Cubit<InsightsState> {
      final ApiService _apiService;

      InsightsCubit({ApiService? apiService})
          : _apiService = apiService ?? ApiService.instance,
            super(const InsightsState());
    }
    ```
  * Это правило обязательно, так как позволяет безболезненно подменять сервисы моками (`mocktail`) в `bloc_test`.

---

## 3. Управление жизненным циклом и ресурсами

* **Отмена сетевых запросов (`CancelToken`)**:
  * Для длительных или повторяющихся сетевых вызовов (например, запросы AI-инсайтов или аналитики) обязательно использовать `CancelToken` от Dio:
    ```dart
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    ```
* **Освобождение ресурсов в `close()`**:
  * В переопределенном методе `close()` обязательно отменять активные `CancelToken`, таймеры и подписки на потоки (`StreamSubscription`):
    ```dart
    @override
    Future<void> close() {
      _cancelToken?.cancel();
      _authSubscription?.cancel();
      return super.close();
    }
    ```

---

## 4. Обработка ошибок в состояниях

* Ошибки сетевого клиента (`DioException`), тайм-ауты или сбои сериализации оборачиваются в человекочитаемые сообщения и типизированные флаги состояния (например, `syncError`, `rateLimitSeconds`, `isServiceUnavailable`).
* В состоянии рекомендуется поддерживать статус перечисления (Enum: `initial`, `loading`, `success`, `failure`), что упрощает обработку состояний в виджетах.
