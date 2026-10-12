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
├── main.dart                    # Точка входа: .env -> локальная БД -> ApiService.init -> runApp (адаптивная ориентация, AppTheme)
├── config/
│   ├── api_config.dart          # Пути эндпоинтов; ApiConfig.baseUrl делегирует в EnvironmentConfig
│   └── environment.dart         # Окружения prod/dev/local, выбор в debug (SharedPreferences), в release всегда prod
├── theme/
│   ├── app_theme.dart           # Конфигурация светлой и тёмной тем (Material 3, ColorScheme, палитра)
│   └── theme.dart               # Barrel-файл экспорта темы
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
│   ├── currency_exchange_service.dart # Конвертация и актуализация курсов валют (офлайн fallback).
│   │                                 # При смене базовой валюты Presentation-слой динамически пересчитывает суммы
│   │                                 # в представлении (on-the-fly) без мутации исторической базы и без ложных флагов isModified.
│   ├── tracing_interceptor.dart  # Сквозная трассировка сетевых запросов (X-Request-ID)
│   └── pending_deletions_store.dart # Очередь отложенных удалений
├── cubits/
│   ├── auth/                    # AuthCubit: глобальное состояние авторизации
│   ├── insights/                # InsightsCubit: загрузка AI-инсайтов, отмена запросов, реакция на смену валюты/языка
│   └── profile/                 # ProfileCubit: статус авторизации, облачная синхронизация, выход
├── widgets/
│   ├── dashboard/               # Декомпозированные виджеты экрана дашборда (баннер гостя, тайлы, группы)
│   ├── budgets/                 # Декомпозированные виджеты экрана бюджетов (селектор периода, карточка, лист)
│   ├── profile/                 # Декомпозированные виджеты профиля (шапка, синк, настройки, версия с таймером)
│   ├── glass_container.dart     # Переиспользуемый контейнер Liquid Glass с BackdropFilter и световой гранью
│   ├── liquid_glass_nav_bar.dart# Плавающий островок навигации Liquid Glass в стиле One UI / Galaxy Store
│   ├── liquid_glass_fab.dart    # Плавающая кнопка действия с градиентным стеклом и неоновым свечением
│   └── welcome_language_sheet.dart # Выбор стартового языка приложения
└── screens/
    ├── main_shell.dart            # Каркас с навигацией и слушателем сессии
    ├── dashboard_screen.dart      # Баланс и список операций
    ├── add_transaction_sheet.dart # Форма добавления транзакции
    ├── budgets_screen.dart        # Лимиты бюджета
    ├── insights_screen.dart       # AI-инсайты
    ├── profile_screen.dart        # Профиль пользователя и настройки приложения
    ├── auth_screen.dart           # Вход и регистрация
    ├── debug_menu_screen.dart     # Скрытое меню отладки (локализовано, токены Material 3)
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
- **Синхронизация и защита целостности данных (Sync Integrity & ETag Lifecycle)**:
  - **Привязка ETag к пользователю и окружению**: ETag сохраняется в защищенном хранилище по составному ключу `${entity}_etag_${userId}_${env}`, что исключает коллизии между сессиями разных пользователей и средами (dev/prod).
  - **Подавление ETag при пустой локальной базе**: Если локальная база пуста (`!LocalDbService.instance.hasTransactions`), заголовок `If-None-Match` намеренно не отправляется. Это предотвращает ошибочный ответ 304 Not Modified после переустановки приложения или очистки локальной базы при сохранившемся в Keychain ключе ETag.
  - **Атомарная фиксация ETag после пагинации**: ETag сохраняется в хранилище **строго после успешной и полной загрузки всех страниц** (`hasMore == false`, `isComplete == true`). При сбое сети или тайм-ауте на 2..N страницах ETag не обновляется.
  - **Защита от удаления локальных записей при неполной выгрузке**: Если выгрузка с сервера завершилась не полностью (ошибка сети в цикле пагинации или исчерпание лимита `maxPages`), `SyncService` выполняет безопасный `LocalDbService.upsertRemoteTransactions` (или `reconcileTransactions(..., removeStale: false)`). Локальные записи не удаляются, предотвращая потерю данных при частичных сетевых сбоях.
  - **Типизированные исключения синхронизации (`SyncException`)**: Внутренние ошибки `SyncService` типизированы через `SyncErrorCode` (`unauthorized`, `networkError`, `serverError`, `dataError`, `unknown`). Сообщения об ошибках локализуются на уровне представления через `AppErrorHandler` и `AppLocalizations`.
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

## Пользовательский интерфейс, темы и верстка (UI & Design System)

- **Дизайн-система и темы (`lib/theme/app_theme.dart`)**:
  - Все цвета и параметры тем вынесены из `main.dart` в единый класс `AppTheme`.
  - Поддерживаются `AppTheme.lightTheme` и `AppTheme.darkTheme` на базе Material 3 с палитрами `colorScheme` (основной цвет — `primaryTeal` `#0D9488`, фоны `#F8FAFC` и `#0F172A`, карточки `#FFFFFF` и `#1E293B`, границы `#E2E8F0` и `#334155`).
  - Во всех экранах и виджетах устранены прямые константы цветов (`Colors.grey/red/orange/...`); стилизация выполняется строго через `Theme.of(context).colorScheme` и `Theme.of(context).textTheme`.
  - Сконфигурирована глобальная `inputDecorationTheme` для светлой и темной тем со скруглением 16px, аккуратными границами и красным контуром ошибки (`errorBorder` и `focusedErrorBorder` на базе `AppTheme.errorRed`).

- **Архитектура интерфейса Liquid Glass (Полированное жидкое стекло)**:
  - **Дизайн-система токенов стекла (`ThemeExtension<GlassTheme>`)**:
    - Централизованные токены стекла вынесены в `GlassTheme` (`surface`, `surfaceEnd`, `rim`, `shadow`, `accent`, `activeItemBg`, `inactiveItemColor`, `toastSurface`, `toastRim`, `blurSigma = 18.0`).
    - Поддерживаются светлая и темная темы с контрастом неактивных пунктов по стандарту WCAG AA (> 4.5:1).
    - Универсальный компонент `GlassContainer` автоматически использует токены из `GlassTheme.of(context)` и устраняет просвечивание темной тени сквозь стекло за счет `spreadRadius: -2`.
  - **Плавающий островок навигации в Stack (`LiquidGlassNavBar`)**:
    - Навигационная панель вынесена из слота `bottomNavigationBar` Scaffold в плавающий оверлей `Stack(alignment: Alignment.bottomCenter)` с `Positioned(bottom: 0)`.
    - Обернута в `RepaintBoundary` для изоляции перерисовок, а радиус размытия оптимизирован до `sigma: 18.0`.
    - Поддерживает доступность через `Semantics(button: true, selected: isSelected, label: item.label)`, ограничение масштабирования текста `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` и тактильно-визуальный отклик нажатия с микро-анимацией масштаба (`AnimatedScale` 0.94 на tap-down).
  - **Централизованные метрики высоты и адаптивные отступы**:
    - Устранены дублирующиеся магические числа (68.0, 140.0, 120.0). Расчет отступов централизован в хелперах `LiquidGlassNavBar.totalHeight(context)`, `bottomContentPadding(context)` и `fabBottomPadding(context)` на базе `MediaQuery.paddingOf(context)`.
    - Всплывающие уведомления `AppAlerts` (SnackBar) используют `SnackBarBehavior.floating` с `margin.bottom = totalHeight + 8.0`, предотвращая перекрытие тостов плавающим навбаром.
  - **Плавающая кнопка действия (`LiquidGlassFab`)**:
    - Стилизована через палитру темы (`colorScheme.primary`/`secondary`/`onPrimary`) без хардкода цветов.
    - Включает полную поддержку доступности (`Tooltip`, `Semantics`) с локализованными подсказками.

- **Инлайн-валидация полей ввода (Inline Input Validation & Error Styling)**:
  - Вывод ошибок валидации полей ввода отвязан от всплывающих алертов и тостов (`AppAlerts.warning`/`SnackBar`).
  - При ошибке валидации поле подсвечивается красным контуром, а под полем выводится компактное и емкое сообщение требования (`amount_requirement_enter`, `amount_requirement_positive`, `amount_requirement_max`).
  - Ошибка автоматически очищается в реальном времени при вводе символов пользователем или смене валюты.
  - Формы ввода в модальных листах (`AddTransactionSheet`, `AddBudgetSheet`) защищены от переполнения экрана при появлении ошибки и клавиатуры через `SingleChildScrollView`.

- **Декомпозиция крупных экранов**:
  - `DashboardScreen`: декомпозирован на `GuestModeBanner`, `TransactionItemTile`, `CategoryGroupWidget`, `DayGroupWidget`, `DashboardPeriodPickerSheet` (директория `lib/widgets/dashboard/`).
    - `CategoryGroupWidget` суммирует итог категории строго в базовой валюте пользователя (`effectiveBaseAmount`) со знаком валюты, обеспечивая 100% сходимость с общим балансом дашборда. При наличии мультивалютных трат выводит подстроку с оригинальной валютой чека, счетчик операций с корректным склонением (`LanguageManager.formatOperationsCount`) и анимированный шеврон раскрытия аккордеона (`AnimatedRotation`).
  - `BudgetsScreen`: декомпозирован на `BudgetPeriodSelector`, `BudgetItemCard`, `AddBudgetSheet` (`lib/widgets/budgets/`).
  - `ProfileScreen`: декомпозирован на `ProfileHeader`, `ProfileSyncCard`, `ProfileSettingsCard`, `ProfileAppVersion`, `CurrencyPickerSheet`, `LanguagePickerSheet` (`lib/widgets/profile/`).
  - Методы `_buildX` заменены на независимые StatelessWidget / StatefulWidget с чистым контрактом передачи параметров и колбэков.

- **Жизненный цикл провайдеров в `main.dart`**:
  - `BlocProvider<AuthCubit>` вынесен на самый верхний уровень над `ValueListenableBuilder` темы и языка, исключая пересоздание `AuthCubit` и сброс его подписок при динамическом переключении настроек пользователем.

- **Адаптивная ориентация устройств**:
  - В `main.dart` перед установкой `SystemChrome.setPreferredOrientations` проверяется размер экрана: для планшетов и iPad (`shortestSide >= 600`) разрешены все 4 ориентации (`portraitUp`, `portraitDown`, `landscapeLeft`, `landscapeRight`) для соответствия гайдлайнам App Store/Google Play, в то время как телефоны работают в портретном режиме.

- **Скрытое Debug-меню (`DebugMenuScreen`)**:
  - Активируется 5 тапами по плашке версии приложения в профиле (`ProfileAppVersion`).
  - Добавлен `Timer` на 2 секунды для сброса счётчика тапов при паузе.
  - При 2–4 тапах отображается всплывающее уведомление (SnackBar) с подсказкой об оставшемся числе тапов.
  - Тексты и элементы меню отладки полностью интернационализированы (`AppLocalizations`) на русском, узбекском и английском языках, цвета синхронизированы с текущей темой.

- **Мультивалютная архитектура (Clean Multi-Currency Architecture)**:
  - **Принцип неизменяемости фактов (Fact Immutability)**: В локальной БД (`ObjectBox`) транзакция сохраняет неизменный физический факт чека (`amount`, `currencyCode`), а также курс и базовую сумму на момент совершения операции.
  - **Динамический пересчет в представлении (On-the-fly Presentation Conversion)**: При смене базовой валюты пользователя в профиле (или на онбординге) база данных **не мутируется**, а исторические записи **не перезаписываются**. Месячные агрегации (`LocalDbService.getMonthTotals`, `getSpentForCategory`) и отображение элементов (`effectiveBaseAmount`, `effectiveExchangeRate`) вычисляются динамически на лету через `CurrencyExchangeService` за доли миллисекунды.
  - **Чистота синхронизации (Sync Integrity)**: Исключены паразитные выставления флагов `isModified = true` и массовые сетевые перезаписи базы на бэкенд при смене валюты отображения.
  - **Изоляция выбора валюты**: Виджет `CurrencyPickerSheet` разделяет смену глобальной валюты аккаунта (`updateGlobalCurrency: true` в профиле) и выбор локальной валюты конкретной операции (`updateGlobalCurrency: false` в формах транзакций и бюджетов).
  - **Приоритетная загрузка курсов с бэкенда (`/currencies/rates`)**: В `CurrencyExchangeService.fetchLatestRates` запросы первоочередно направляются на собственный бэкенд (`${ApiConfig.currencyRates}`). При недоступности или ошибке сервера предусмотрен каскадный Graceful Fallback на открытый шлюз (`open.er-api.com`), локальный кэш `PreferencesService` и встроенные резервные котировки.
  - **Санитизация и валидация курсов валют**: Любые получаемые курсы (с бэкенда, шлюзов или из локального хранилища) проходят строгую валидацию `val > 0 && val.isFinite`. Нулевые, отрицательные или NaN/Infinity значения отбрасываются с логированием `AppLogger.w`, а конвертер использует безопасные fallback-курсы (`_fallbackRatesToUsd`), предотвращая неконтролируемое сведение курса к 1.0.
  - **Отслеживание актуальности котировок**: `CurrencyExchangeService` предоставляет геттеры `isOutdated` (возраст котировок >= 24 часов) и `isApproximate`. При устаревании курсов экран ввода транзакции (`AddTransactionSheet`) выводит информационную плашку с датой обновления или пометкой приблизительного курса.
  - **Локализованное форматирование и парсинг валют (`CurrencyFormatter`)**: Поддерживаются региональные правила форматирования с учетом локали (`en`: запятая как разделитель тысяч, точка для копеек, e.g. `$1,234.56`; `ru`/`uz`: неразрывный пробел и запятая). Парсер `CurrencyFormatter.parseInput` универсально распознает оба формата разделителей.
  - **Защищенный ввод сумм (`CurrencyInputFormatter`)**: Очистка ведущих нулей выполняется через регулярное выражение `replaceFirst(RegExp(r'^0+(?=\d)'), '')` на строковом уровне без промежуточного `int.parse`, что исключает переполнение 64-битных целых чисел при вставке длинных последовательностей цифр. Длина целой части ограничена `maxIntDigits`.
  - **Атомарная инвалидация ETag и фоновая синхронизация**: При смене базовой валюты пользователя (`AuthApiService.updateUserProfile(baseCurrency: ...)`) бэкенд атомарно пересчитывает исторические данные. Мобильный клиент удаляет заголовки `transactions_etag` и `budgets_etag` из безопасного хранилища (`FlutterSecureStorage`), сбрасывает кэш ETag в `SyncService` и запускает фоновый `ApiService.syncAll()`, обновляя интерфейсы через `CurrencyFormatter.notifyCurrencyChanged()`.
  - **Безопасность котировок и сетевого слоя (Rate Sanity & Network Security, Block B)**:
    - **Единый сетевой клиент**: `CurrencyExchangeService` переведен на использование единого экземпляра `ApiService.instance.dio`, обеспечивающего сквозную трассировку через `TracingInterceptor` (`X-Request-ID`), централизованное логирование сетевых событий в `AppLogger` и единообразные сетевые таймауты.
    - **Изоляция заголовка Authorization**: В перехватчике `ApiService` реализована строгая фильтрация целевых хостов (`_isAuthExcludedPath`). Любые запросы к внешним шлюзам (включая fallback на `open.er-api.com`) и публичным эндпоинтам котировок (`/currencies/rates`) гарантированно исключают передачу заголовка `Authorization: Bearer <jwt>`, предотвращая утечку токенов сессии пользователя на сторонние ресурсы. Ошибки HTTP 401 на внешних хостах не приводят к циклическому обновлению токенов бэкенда.
    - **Контроль аномалий котировок (Sanity Bounds)**: Для защиты от некорректных или скомпрометированных ответов внешних шлюзов реализован метод `_isRateWithinSanityBounds`. Котировки валидируются на допустимое отклонение относительно базовых/кэшированных значений: отклонения более чем в 2 раза (>2.0x или <0.5x от baseline) признаются аномальными, логируются в `AppLogger.w` и отбрасываются с сохранением предыдущих проверенных курсов.

