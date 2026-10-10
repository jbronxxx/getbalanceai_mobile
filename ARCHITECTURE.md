# Архитектура GetBalance AI (getbalanceai_mobile)

Кроссплатформенное Flutter-приложение для учёта личных/семейных финансов.
Работает офлайн-first: все данные сначала пишутся в локальную базу на
устройстве, синхронизация с бэкендом — отдельный, пока частично
реализованный слой.

## Технологический стек

| Слой                   | Технология                                                         |
|------------------------|--------------------------------------------------------------------|
| UI                     | Flutter (Material 3)                                               |
| Управление состоянием  | [flutter_bloc](https://pub.dev/packages/flutter_bloc) (Cubit)      |
| Локальное хранилище    | [ObjectBox](https://objectbox.io/) (NoSQL, встроенная БД)          |
| Сетевой клиент         | [Dio](https://pub.dev/packages/dio)                                |
| Конфигурация           | [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) (`.env`) |
| Управление версией SDK | [FVM](https://fvm.app/) (см. `.fvmrc`, Flutter 3.29.3)             |

Бэкенд (FastAPI) в этот репозиторий не входит — приложение общается с ним
только по REST API, описанному в `lib/config/api_config.dart`.

## Структура `lib/`

```
lib/
├── main.dart                    # Точка входа: .env -> локальная БД -> ApiService.init -> runApp
├── config/
│   ├── api_config.dart          # Пути эндпоинтов; ApiConfig.baseUrl делегирует в EnvironmentConfig
│   └── environment.dart         # Окружения prod/dev/local, выбор в debug (SharedPreferences), в release всегда prod
├── models/
│   ├── auth_model.dart          # DTO для авторизации (Login, Register, Me)
│   ├── budget_model.dart        # DTO для бюджетов
│   ├── paginated_response.dart  # Универсальный DTO для пагинированных ответов (items, total, limit, offset)
│   ├── transaction_model.dart   # DTO для транзакций (с поддержкой created_at и безопасного парсинга дат)
│   ├── sync_model.dart          # Модель для пакетной синхронизации
│   └── local_db_models.dart     # Сущности ObjectBox (Transaction, Budget)
├── services/
│   ├── api_service.dart          # Единый сетевой фасад (делегирует в Auth/Transaction/Budget/Sync)
│   ├── auth_api_service.dart     # Сервис аутентификации, сессий и токенов
│   ├── transaction_api_service.dart # Сервис API транзакций
│   ├── budget_api_service.dart   # Сервис API бюджетов
│   ├── sync_service.dart         # Двусторонняя синхронизация с бэкендом
│   ├── local_db_service.dart     # Доступ к ObjectBox (singleton)
│   ├── app_info_service.dart     # Кеширование метаданных приложения (версия, сборка)
│   ├── preferences_service.dart  # Настройки (тема, язык, валюта)
│   ├── tracing_interceptor.dart  # Сквозная трассировка сетевых запросов (X-Request-ID)
│   └── pending_deletions_store.dart # Очередь отложенных удалений
├── cubits/
│   ├── auth/                    # AuthCubit: глобальное состояние авторизации
│   ├── insights/                # InsightsCubit: загрузка AI-инсайтов, отмена запросов, реакция на смену валюты/языка
│   └── profile/                 # ProfileCubit: статус авторизации, облачная синхронизация, выход
└── screens/
    ├── main_shell.dart            # Каркас с навигацией и слушателем сессии
    ├── dashboard_screen.dart      # Баланс и список операций
    ├── add_transaction_sheet.dart # Форма добавления транзакции
    ├── budgets_screen.dart        # Лимиты бюджета
    ├── insights_screen.dart       # AI-инсайты
    ├── profile_screen.dart        # Профиль пользователя и настройки приложения
    ├── auth_screen.dart           # Вход и регистрация
    └── service_unavailable_screen.dart # Экран технических работ (HTTP 503)
```

## Правила зависимостей между слоями

```
screens/  --->  cubits/  --->  services/  --->  models/
screens/  --->  services/  --->  models/
screens/  --->  models/
services/ --->  config/
main.dart --->  services/, screens/
```

### Управление состоянием (Cubit)

Бизнес-логика экранов выносится в Cubit-классы (`lib/cubits/<feature>/`),
состояния описываются в `part`-файле `<feature>_state.dart`. Экран создаёт
Cubit через `BlocProvider` и отображает состояние через `BlocBuilder` /
`BlocConsumer`; одноразовые эффекты (алерты, навигация) выполняются в
`listener`, а не в `builder`.

- Зависимости (`ApiService`, `Connectivity`) передаются в конструктор Cubit
  опционально и по умолчанию берутся из синглтонов — это позволяет
  подменять их моками в тестах (`test/cubits_test.dart`, `bloc_test` + `mocktail`).
- Cubit не принимает `BuildContext` и не показывает UI. Ошибки сохраняются
  в состоянии (например, `ProfileState.syncError`) и отображаются экраном.
- Подписки (Stream, `ValueNotifier`) и `CancelToken` освобождаются в `close()`;
  после асинхронных операций проверяется `isClosed` перед `emit`.
- Мигрированы: `insights_screen.dart`, `profile_screen.dart`. Новые экраны
  с сетевой логикой следует сразу писать на Cubit.

Экраны и сервисы **никогда** не импортируют `main.dart`. Раньше это было не
так: глобальный объект `dbService` жил прямо в `main.dart`, и экраны
(`dashboard_screen.dart`, `budgets_screen.dart`, `add_transaction_sheet.dart`)
импортировали его оттуда — получался цикл `main.dart -> screens/... ->
main.dart`. Это было исправлено переносом состояния БД в сам
`LocalDbService` (статическое поле `LocalDbService.instance`,
инициализируется в `main()` через `LocalDbService.init()`). Придерживайтесь
этого правила при добавлении новых сервисов/глобального состояния — не
кладите его в `main.dart`.

## Авторизация и безопасность

- **JWT-авторизация**: Используется пара `access_token` и `refresh_token` с уникальным идентификатором `jti`.
- **Хранение**: Токены сохраняются в `FlutterSecureStorage` (на Android используется `EncryptedSharedPreferences`).
- **Автообновление и защита от гонок**: Реализован `InterceptorsWrapper` в Dio. При конкурентных `401 Unauthorized` обновление токена через `/api/v1/auth/refresh` выполняется ровно один раз с использованием `Completer`, предотвращая гонку сессий. Повторные запросы помечаются флагом `extra['retried'] = true`, исключая зацикливание при повторных 401. Эндпоинты входа и регистрации (`/auth/login`, `/auth/register`, `/auth/google`, `/auth/apple`, `/auth/refresh`) исключены из автообновления и сброса активной сессии.
- **Слушатель сессии**: Глобальный `AuthCubit` подписывается на `ApiService.authStream`, предоставляя состояние авторизации всему приложению через `BlocProvider`. Экраны (например, `MainShell` и `ProfileScreen`) реагируют на изменения состояния и автоматически перенаправляют на `/login` при потере авторизации. При смене окружения через Debug-меню базовый URL Dio обновляется динамически, а сессия и токены предыдущего окружения сбрасываются.

## Локальное хранилище и синхронизация

- `Transaction` и `Budget` — сущности ObjectBox (`@Entity()`).
- **Денежные суммы (Decimal / Numeric(12, 2))**: На бэкенде денежные поля переведены на `Decimal(12, 2)` (`amount`, `limit_amount`, `spent`, `remaining`). На клиенте десериализация моделей (`Transaction`, `Budget`, `TransactionModel`, `BudgetModel`) выполняется через безопасный хелпер `parseAmount()`, корректно обрабатывающий как числовой `num` (int/double), так и строковый формат `"123.45"`, исключая ошибки приведения типов.
- **Временные метки**: Все даты передаются по API в формате UTC ISO 8601 (`.toUtc().toIso8601String()`), а на клиенте разбираются через `.toLocal()`.
- **Пагинация транзакций (API GET /api/v1/transactions/)**: Эндпоинт поддерживает Query-параметры `limit` (1..100, default 50), `offset` (min 0) и `since` (ISO 8601). Ответ бэкенда возвращается в формате `PaginatedResponse<TransactionModel>` (`items`, `total`, `limit`, `offset`). Фоновый процесс синхронизации `syncBackendDataToLocal` прозрачно выкачивает страницы с поддержкой отслеживания прогресса (`onTransactionProgress`) и защитой от переполнения памяти/бесконечных циклов через лимит `maxPages`.
- **Синхронизация**: Двусторонняя (push/pull).
  - `syncLocalDataToBackend`: Отправляет локальные записи без `serverId`, а для офлайн-удаленных бюджетов передает `is_deleted: true` и массив `deleted_budget_ids`.
  - `syncBackendDataToLocal`: Загружает актуальные данные с сервера и сверяет с локальными. Процесс сверки (`reconcileTransactions`, `reconcileBudgets`) оптимизирован по потреблению памяти: поиск устаревших локальных записей выполняется таргетированными запросами ObjectBox, минуя загрузку всей базы в Dart heap.
  - `PendingDeletionsStore`: Хранит ID удаленных локально транзакций и бюджетов (tombstones), чтобы синхронизировать удаление на сервере при появлении сети.

## Наблюдаемость и обработка сбоев (Observability & Error Handling)

- **Логирование и отладка**: Единый логгер `AppLogger` (`lib/utils/app_logger.dart`) направляет все сообщения в `talker` (Talker, активен только в debug). Зависимость `package:logger` удалена, устранено дублирование. HTTP-трафик в debug пишет `TalkerDioLogger`. Скрытое Debug-меню (`DebugMenuScreen`, не работает в release) позволяет сменить окружение, просматривать логи Talker и очистить кеш/токены.
- **Сквозная трассировка (X-Request-ID)**: В сетевом клиенте Dio зарегистрирован `TracingInterceptor`. Для каждого исходящего запроса генерируется UUID v4 (или сохраняется существующий заголовок `X-Request-ID`). При сбоях или ответах идентификатор запроса извлекается из заголовков ответа (`x-request-id`) или запроса и передается в `AppLogger` для упрощения диагностики и корреляции с бэкендом.
- **Ограничение частоты запросов (Rate Limiting HTTP 429 / RATE_LIMIT_EXCEEDED)**:
  - Эндпоинты аутентификации (`/api/v1/auth/login`, `/api/v1/auth/register`) ограничены лимитом 5 запросов в минуту на IP.
  - Эндпоинт аналитики (`/api/v1/insights/`) ограничен лимитом 10 запросов в минуту.
  - При получении HTTP 429 или кода `RATE_LIMIT_EXCEEDED`, `AppErrorHandler` перехватывает ошибку, считывает заголовок `Retry-After` и открывает модальное окно `AppAlerts.showRateLimitDialog` с динамическим таймером обратного отсчета до возможности повторного запроса.

- **Обработка HTTP 503 (Service Unavailable)**: При получении статуса HTTP 503 или кода ошибки `SERVICE_UNAVAILABLE` (например, при технических работах или недоступности бэкенда/эндпоинта `/health`), `AppErrorHandler` перехватывает ошибку и отображает модальный диалог `AppAlerts.showServiceUnavailableDialog` либо перенаправляет на экран `ServiceUnavailableScreen` с поддержкой повтора запроса (`onRetry`) и полной мультиязычностью (RU, UZ, EN).




