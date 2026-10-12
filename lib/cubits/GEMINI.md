# Правила Cubit (lib/cubits/)

* Без `BuildContext`, навигации, диалогов, `ScaffoldMessenger` — сайд-эффекты через состояние + `BlocListener`.
* Иммутабельные состояния, изменение через `copyWith`; статус-enum `initial|loading|success|failure`.
* После каждого `await` перед `emit()`: `if (isClosed) return;`.
* Структура: `lib/cubits/<feature>/<feature>_cubit.dart` + `<feature>_state.dart` (`part of`).
* DI для тестов — опциональные именованные параметры с fallback на синглтон:
  ```dart
  InsightsCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(const InsightsState());
  ```
* Длительные/повторные запросы: `_cancelToken?.cancel(); _cancelToken = CancelToken();`.
* В `close()` отменять `CancelToken`, таймеры, `StreamSubscription`, затем `super.close()`.
* `DioException`/таймауты/ошибки парсинга → понятное сообщение + типизированные поля (`syncError`, `rateLimitSeconds`, `isServiceUnavailable`).
