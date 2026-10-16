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
| Конфигурация           | `--dart-define` / [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) |
| Управление версией SDK | [FVM](https://fvm.app/) (см. `.fvmrc`, Flutter 3.29.3)             |
| Минимальные платформы  | iOS 15.0 (требование Xcode 27), Android — `minSdk` из Flutter      |

Бэкенд (FastAPI) в этот репозиторий не входит — приложение общается с ним
только по REST API, описанному в `lib/config/api_config.dart`.

## Структура `lib/`

```
lib/
├── main.dart                    # Точка входа: config -> локальная БД -> ApiService.init -> runApp (адаптивная ориентация, AppTheme, GetBalance AI)
├── config/
│   ├── api_config.dart          # Пути эндпоинтов; ApiConfig.baseUrl делегирует в EnvironmentConfig
│   └── environment.dart         # Окружения prod/dev/local (.env в debug, --dart-define в release), в release всегда prod
├── theme/
│   ├── app_theme.dart           # Конфигурация светлой и тёмной тем (Material 3, ColorScheme, палитра)
│   └── theme.dart               # Barrel-файл экспорта темы
├── models/
│   ├── auth_model.dart          # DTO для авторизации (Login, Register, Me)
│   ├── budget_model.dart        # DTO для бюджетов
│   ├── report_model.dart        # Отчёты: ReportPeriod, ReportFormat, ReportData (операции, итоги, лимиты) — чистые Dart-типы
│   ├── paginated_response.dart  # Универсальный DTO для пагинированных ответов (items, has_more, next_cursor, limit)
│   ├── transaction_model.dart   # DTO для транзакций (с поддержкой created_at и безопасного парсинга дат)
│   ├── sync_model.dart          # Модель для пакетной синхронизации
│   ├── local_db_models.dart     # Сущности ObjectBox (Transaction, Budget)
│   ├── month_budget_summary.dart # MonthBudgetSummary: лимиты, потрачено, остаток и «можно тратить в день» за месяц
│   └── month_period.dart        # MonthPeriod: календарный месяц (переходы через границу года, сравнение)
├── services/
│   ├── api_service.dart          # Единый сетевой фасад (делегирует в Auth/Transaction/Budget/Sync)
│   ├── auth_api_service.dart     # Сервис аутентификации, сессий и токенов
│   ├── transaction_api_service.dart # Сервис API транзакций
│   ├── budget_api_service.dart   # Сервис API бюджетов
│   ├── sync_service.dart         # Двусторонняя синхронизация с бэкендом
│   ├── local_db_service.dart     # Доступ к ObjectBox (singleton); статический transactionsChanged — сигнал вкладкам об изменении данных (сохранение/удаление операции, загрузка с сервера)
│   ├── app_info_service.dart     # Кеширование метаданных приложения (версия, сборка)
│   ├── preferences_service.dart  # Настройки (тема, язык, валюта)
│   ├── selected_period_service.dart # Общий выбранный месяц для вкладок «Баланс», «Бюджет», «Аналитика» (ValueNotifier, ±5 лет)
│   ├── currency_exchange_service.dart # Конвертация и актуализация курсов валют (офлайн fallback).
│   │                                 # При смене базовой валюты Presentation-слой динамически пересчитывает суммы
│   │                                 # в представлении (on-the-fly) без мутации исторической базы и без ложных флагов isModified.
│   ├── entitlement_service.dart  # Доступ к платным функциям (AppFeature); до монетизации всё открыто
│   ├── report_data_service.dart  # Сборка ReportData из ObjectBox за период, конвертация в базовую валюту
│   ├── csv_report_generator.dart # CSV (UTF-8 BOM, диалект по языку, защита от формул)
│   ├── pdf_report_generator.dart # PDF (пакет pdf, шрифт Inter из ассетов): сводка, категории, лимиты, операции
│   ├── report_export_service.dart # Доставка файла: «Поделиться» (временный файл + share_plus) или «Сохранить» (системный диалог file_picker.saveFile)
│   ├── device_capability_service.dart # Определение аппаратных возможностей устройства (поддержка RenderEffect/BackdropFilter, Android API < 31)
│   ├── tracing_interceptor.dart  # Сквозная трассировка сетевых запросов (X-Request-ID)
│   ├── pending_deletions_store.dart # Очередь отложенных удалений
│   └── undoable_deletions.dart  # Удаление операций и лимитов с отменой: скрыть сразу, удалить из базы и с сервера через 5 с, если не нажали «Отменить»
├── cubits/
│   ├── auth/                    # AuthCubit: глобальное состояние авторизации
│   ├── report_export/           # ReportExportCubit: период (месяц/год/свой диапазон), формат CSV/PDF, проверка доступа и выгрузка
│   ├── insights/                # InsightsCubit: загрузка AI-инсайтов с фильтрацией по периоду (month, year), отмена запросов, реакция на смену валюты/языка/авторизации
│   └── profile/                 # ProfileCubit: статус авторизации, облачная синхронизация, выход
├── widgets/
│   ├── dashboard/               # Лента дашборда: группа дня, группа категории за месяц, переключатель вида, строка и карточка операции, действие аккаунта, баннер гостя
│   ├── category_style.dart      # CategoryStyle: иконка и цвет категории (лента, чипы формы, инфографика)
│   ├── budgets/                 # Вкладка «Бюджет»: карточка бюджета месяца, карточка лимита, заголовок блока, кольцо структуры расходов
│   ├── insights/                # Вкладка «Аналитика»: секция структуры расходов, карточки «нечего анализировать» и «сформировать анализ», выгрузка отчёта (кнопка + лист)
│   ├── period/                  # PeriodSwitcher «‹ Октябрь ›» и PeriodPickerSheet (год + сетка месяцев)
│   ├── transaction/             # Части формы операции: тип, сумма с валютой, выбор дня, чипы категорий и лист всех категорий
│   ├── profile/                 # Декомпозированные виджеты профиля (шапка, синк, настройки, данные, версия с таймером)
│   ├── ai_sparkles_loader.dart  # Анимированный лоадер генерации ИИ (пульсирующие звёздочки)
│   ├── custom_pull_to_refresh.dart # Кастомный Pull-to-Refresh со шторкой и режимом releaseImmediately
│   ├── glass_container.dart     # Переиспользуемый контейнер Liquid Glass с BackdropFilter, RepaintBoundary и непрозрачным fallback
│   ├── keyboard_inset_padding.dart # Отступ модального листа под клавиатуру (подписан только на viewInsets, содержимое листа не перестраивается)
│   ├── keyboard_insets_isolation.dart # Скрывает клавиатуру от экранов под модальным листом (MainShell): кадры её анимации не перестраивают вкладки и навбар
│   ├── liquid_glass_app_bar.dart# Хэдер экрана из полированного полупрозрачного стекла со скругленным низом (20px, BackdropFilter, topContentPadding)
│   ├── liquid_glass_nav_bar.dart# Плавающий островок навигации Liquid Glass с единой полупрозрачностью и блюром (RepaintBoundary, sigma 18)
│   ├── liquid_glass_fab.dart    # Кнопка действия с градиентным стеклом и неоновым свечением (центральная «+» навбара)
│   ├── screen_body_card.dart    # Каркас контента экрана со скругленными верхними краями (28px) и бесшовным скольжением под хэдер
│   └── welcome_language_sheet.dart # Выбор стартового языка приложения
└── screens/
    ├── main_shell.dart            # Каркас с IndexedStack, сохранением состояния вкладок (PageStorageKey) и локализацией слушателя валюты
    ├── dashboard_screen.dart      # Баланс и список операций
    ├── add_transaction_sheet.dart # Форма добавления транзакции
    ├── budgets_screen.dart        # «Бюджет»: бюджет месяца, лимиты по категориям
    ├── insights_screen.dart       # «Аналитика»: структура расходов, AI-советы за месяц, выгрузка отчёта в шапке
    ├── profile_screen.dart        # Профиль пользователя и настройки приложения
    ├── auth_screen.dart           # Вход и регистрация
    ├── welcome_setup_screen.dart  # Экран пошагового онбординга (выбор языка интерфейса и базовой валюты)
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
- **Пагинация транзакций (API GET /api/v1/transactions/)**: курсорная (keyset). Query-параметры: `limit` (1..100, default 50), `cursor` (непрозрачная строка из `next_cursor` предыдущей страницы; без него — первая страница) и `since` (ISO 8601, фильтр по `created_at`). Ответ — `PaginatedResponse<TransactionModel>` (`items`, `has_more`, `next_cursor`, `limit`); страницы упорядочены по дате операции от новых к старым. ETag и `If-None-Match` (ответ `304`) применяются только к первой странице. Фоновый процесс синхронизации `syncBackendDataToLocal` прозрачно выкачивает страницы с поддержкой отслеживания прогресса (`onTransactionProgress`) и защитой от переполнения памяти/бесконечных циклов через лимит `maxPages`.
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
  - **Автоматическая фоновая выгрузка (Automatic Background Push)**: При сохранении транзакции (`AddTransactionSheet`) или лимита бюджета (`AddBudgetSheet`) в авторизованном состоянии (`ApiService.isAuthenticated`) запускается неблокирующий фоновый синк `unawaited(ApiService.instance.syncLocalDataToBackend().catchError(...))`. При удалении записей методы `deleteTransactionEverywhere` и `deleteBudgetEverywhere` сохраняют tombstones в `PendingDeletionsStore` и обрабатываются асинхронно без блокировки UI.
  - **Предварительная дозагрузка перед расчетом AI-аналитики (Pre-insights Push Sync)**: Перед выполнением запроса `GET /insights/` (с параметрами `currency`, `locale`, `month`, `year`) в `InsightsCubit.loadInsights()` клиент проверяет наличие локальных невыгруженных записей (`LocalDbService.isInitialized && (LocalDbService.instance.getUnsyncedTransactions().isNotEmpty || LocalDbService.instance.getUnsyncedBudgets().isNotEmpty)`). При их обнаружении сначала выполняется `await _api.syncLocalDataToBackend()`, что гарантирует учет свежих транзакций на бэкенде до генерации рекомендаций. Возможные сбои синка логируются через `AppLogger.w` и не прерывают запрос аналитики.

## Наблюдаемость и обработка сбоев (Observability & Error Handling)

- **Логирование и отладка**: Единый логгер `AppLogger` (`lib/utils/app_logger.dart`) направляет все сообщения в `talker` (Talker, активен только в debug). Зависимость `package:logger` удалена, устранено дублирование. HTTP-трафик в debug пишет `TalkerDioLogger`. Скрытое Debug-меню (`DebugMenuScreen`, не работает в release) позволяет сменить окружение, просматривать логи Talker и очистить кеш/токены.
- **Сквозная трассировка (X-Request-ID)**: В сетевом клиенте Dio зарегистрирован `TracingInterceptor`. Для каждого исходящего запроса генерируется UUID v4 (или сохраняется существующий заголовок `X-Request-ID`). При сбоях или ответах идентификатор запроса извлекается из заголовков ответа (`x-request-id`) или запроса и передается в `AppLogger` для упрощения диагностики и корреляции с бэкендом.
- **Ограничение частоты запросов (Rate Limiting HTTP 429 / RATE_LIMIT_EXCEEDED)**:
  - Эндпоинты аутентификации (`/api/v1/auth/login`, `/api/v1/auth/register`) ограничены лимитом 5 запросов в минуту на IP.
  - Эндпоинт аналитики (`/api/v1/insights/`) ограничен лимитом 10 запросов в минуту.
  - При получении HTTP 429 или кода `RATE_LIMIT_EXCEEDED`, `AppErrorHandler` перехватывает ошибку, считывает заголовок `Retry-After` и открывает модальное окно `AppAlerts.showRateLimitDialog` с динамическим таймером обратного отсчета до возможности повторного запроса.

- **Обработка HTTP 503 (Service Unavailable)**: При получении статуса HTTP 503 или кода ошибки `SERVICE_UNAVAILABLE` (например, при технических работах или недоступности бэкенда/эндпоинта `/health`), `AppErrorHandler` перехватывает ошибку и отображает модальный диалог `AppAlerts.showServiceUnavailableDialog` либо перенаправляет на экран `ServiceUnavailableScreen` с поддержкой повтора запроса (`onRetry`) и полной мультиязычностью (RU, UZ, KK, EN).

## Пользовательский интерфейс, темы и верстка (UI & Design System)

- **Дизайн-токены (`lib/theme/app_colors.dart`, `lib/theme/app_typography.dart`)**:
  - `AppColors` (`ThemeExtension`, `AppColors.of(context)`) — семантические цвета сверх `ColorScheme` для светлой и тёмной темы: фон экранов (`shellBackground`), листы (`sheetBackground/Border/Shadow`, `sheetHandleDark`), карточки (`cardBackground`, `cardGlassBackground`, `cardBorder`, `cardDivider`, `cardShadow`), заливка стекла без размытия (`glassFallbackStart/End`), поля и списки, фирменная карточка (`brandGradient`, `brandShadow`, `onBrand`), бюджет (`warning`, `exceeded` — в светлой теме #B45309/#C2410C, чтобы текст на белой и подкрашенной карточке был не ниже 4.5:1; `exceededOnBrand`, `overspendBadge`), плашка pull-to-refresh. Без расширения в теме (изолированные тесты) берутся значения по яркости.
  - **`accentText`** — бирюзовый для текста и иконок. В светлой теме совпадает с `primary` (#0F766E), в тёмной — #2DD4BF: `primary` на тёмных фонах давал 3.2–3.6:1 при норме WCAG AA 4.5:1. Заливки кнопок и рамки по-прежнему используют `primary` (для графики достаточно 3:1). Контраст закреплён тестом `design_tokens_test.dart`.
  - Палитры категорий — в `CategoryStyle` (`icon`, `color`, `chartColor` — пастель для диаграмм на фирменной карточке).
  - Оформление модальных листов — `AppSheet.decoration(context)` и `SheetHandle` (`lib/widgets/app_sheet.dart`), одинаковое для всех листов.
  - `AppFontSize` — шкала размеров шрифта (micro 10 … headline 20) для ролей, которых нет в `TextTheme`; `AppTypography.screenTitle` — заголовок экрана в стеклянной шапке. В экранах и виджетах нет `Color(0x…)` и числовых `fontSize`; исключения — пропорциональные инициалы `UserAvatar` и PDF-отчёт (`PdfColors`). Кнопки входа Google/Apple — токены `googleButtonBackground/Text`, `appleButtonBackground`. Вместо `Colors.*` — статические основы `AppColors.transparent`, `shadowBase` (тени, затемнения), `highlightBase` (блики и контуры стекла), `onBrandBase` (текст на фирменной карточке); их можно использовать и в `const`.
- **Дизайн-система и темы (`lib/theme/app_theme.dart`)**:
  - Все цвета и параметры тем вынесены из `main.dart` в единый класс `AppTheme`.
  - Поддерживаются `AppTheme.lightTheme` и `AppTheme.darkTheme` на базе Material 3 с палитрами `colorScheme` (основной цвет — `primaryTeal` `#0D9488`, фоны `#F8FAFC` и `#0F172A`, карточки `#FFFFFF` и `#1E293B`, границы `#E2E8F0` и `#334155`).
  - Во всех экранах и виджетах устранены прямые константы цветов (`Colors.grey/red/orange/...`); стилизация выполняется строго через `Theme.of(context).colorScheme` и `Theme.of(context).textTheme`.
  - Сконфигурирована глобальная `inputDecorationTheme` для светлой и темной тем со скруглением 16px, аккуратными границами и красным контуром ошибки (`errorBorder` и `focusedErrorBorder` на базе `AppTheme.errorRed`).
  - **Динамическое переключение тем оформления (`ThemeMode`)**:
    - Поддерживаются 3 режима: `ThemeMode.system` («Системная»), `ThemeMode.light` («Светлая») и `ThemeMode.dark` («Темная»).
    - По умолчанию активен системный режим: приложение динамически следует настройкам темы телефона (при включении темной темы в ОС автоматически применяется `darkTheme`, при выключении — `lightTheme`).
    - Ручной выбор темы осуществляется в профиле (`ProfileSettingsCard`) по аналогии с выбором языка и валюты: через строку меню без лишних иконок и модальный дропдаун-лист `ThemeModePickerSheet`, где варианты выбора отображаются только текстом, а выбранная строка подсвечена цветом темы и отмечена галочкой.
    - Состояние темы управляется через `PreferencesService.instance.themeModeNotifier` с сохранением в `FlutterSecureStorage` (`settings_theme_mode`) и автоматической миграцией с устаревшего булева ключа `settings_dark_mode`.

- **Архитектура интерфейса Liquid Glass (Полированное жидкое стекло)**:
  - **Дизайн-система токенов стекла (`ThemeExtension<GlassTheme>`)**:
    - Централизованные токены стекла вынесены в `GlassTheme` (`surface`, `surfaceEnd`, `rim`, `shadow`, `accent`, `activeItemBg`, `inactiveItemColor`, `toastSurface`, `toastRim`, `blurSigma = 18.0`).
    - Поддерживаются светлая и темная темы с контрастом неактивных пунктов по стандарту WCAG AA (> 4.5:1).
    - Универсальный компонент `GlassContainer` автоматически использует токены из `GlassTheme.of(context)` и устраняет просвечивание темной тени сквозь стекло за счет `spreadRadius: -2`.
  - **Плавающий островок навигации в Stack (`LiquidGlassNavBar`)**:
    - Навигационная панель вынесена из слота `bottomNavigationBar` Scaffold в плавающий оверлей `Stack(alignment: Alignment.bottomCenter)` с `Positioned(bottom: 0)`.
    - Обернута в `RepaintBoundary` для изоляции перерисовок, а радиус размытия оптимизирован до `sigma: 18.0`.
    - Поддерживает доступность через `Semantics(button: true, selected: isSelected, label: item.label)`, ограничение масштабирования текста `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` и тактильно-визуальный отклик нажатия с микро-анимацией масштаба (`AnimatedScale` 0.94 на tap-down).
    - **Тосты при смене вкладки**: `MainShell` закрывает текущий `SnackBar` при переходе на другую вкладку — сообщение относится к вкладке, где появилось.
    - **Центральная кнопка «+» (`LiquidGlassNavAction`)**: `MainShell` передаёт `centerAction`, кнопка (`LiquidGlassFab`, 52pt, полупрозрачная заливка `fillOpacity: 0.82`) стоит между второй и третьей вкладкой. Верхний край островка огибает её дугой с зазором `centerActionGap` (6pt), поднимаясь на `centerActionLift` (22pt): форма `LiquidGlassNavShape` (капсула + дуга со скруглёнными переходами) общая для заливки, блюра (`ClipPath`), контура и тени (`ShapeDecoration`). Высота виджета включает подъём, поэтому вся кнопка принимает нажатия. Подписи вкладок не обрезаются, а уменьшаются (`FittedBox`), если не помещаются. Индексы `destinations` кнопку не учитывают. Кнопка открывает `AddTransactionSheet` с любой вкладки; плавающих FAB на экранах нет.
  - **Централизованные метрики высоты и адаптивные отступы**:
    - Устранены дублирующиеся магические числа (68.0, 140.0, 120.0). Расчет отступов централизован в хелперах `LiquidGlassNavBar.totalHeight(context)` и `bottomContentPadding(context)` (учитывает подъём центральной кнопки) на базе `MediaQuery.paddingOf(context)`.
    - Всплывающие уведомления `AppAlerts` (SnackBar) используют `SnackBarBehavior.floating` с `margin.bottom = totalHeight + centerActionLift + 8.0`, предотвращая перекрытие тостов навбаром и центральной кнопкой.
  - **Кнопка действия (`LiquidGlassFab`)** — используется как центральная «+» навбара:
    - Стилизована через палитру темы (`colorScheme.primary`/`secondary`/`onPrimary`) без хардкода цветов.
    - Включает полную поддержку доступности (`Tooltip`, `Semantics`) с локализованными подсказками.
  - **Хэдер экрана Liquid Glass (`LiquidGlassAppBar`)**:
    - Хэдеры экранов транзакций, лимитов, инсайтов и профиля выполнены в виде полированного полупрозрачного стекла.
    - Реализует `PreferredSizeWidget`, оборачивает `flexibleSpace` в `RepaintBoundary` с размытием `BackdropFilter` (`sigma = 18.0`), градиентной подложкой (`GlassTheme.surface` / `surfaceEnd`), тонкой световой гранью `rim` и рассеянной тенью.
    - Предусмотрен безопасный непрозрачный fallback для устройств без поддержки размытия (Android < API 31).
  - **Каркас экрана с закругленными верхними краями (`ScreenBodyCard`)**:
    - Верхние края основных экранов (транзакции, лимиты, инсайты, профиль) обрамлены скруглением углов `BorderRadius.vertical(top: Radius.circular(28.0))` в стиле M3 Expressive / Sheet.
    - Имеет деликатную верхнюю световую грань и мягкую тень; скроллируемый контент изолирован через `clipBehavior: Clip.antiAlias`, что сохраняет скругления углов при прокрутке.
    - Фоновый цвет каркаса экрана согласуется с `scaffoldBg`, обеспечивая плавный контрастный переход в скругленных углах под стеклянным хэдером.

- **Инлайн-валидация полей ввода (Inline Input Validation & Error Styling)**:
  - Вывод ошибок валидации полей ввода отвязан от всплывающих алертов и тостов (`AppAlerts.warning`/`SnackBar`).
  - При ошибке валидации поле подсвечивается красным контуром, а под полем выводится компактное и емкое сообщение требования (`amount_requirement_enter`, `amount_requirement_positive`, `amount_requirement_max`).
  - Ошибка автоматически очищается в реальном времени при вводе символов пользователем или смене валюты.
  - Формы ввода в модальных листах (`AddTransactionSheet`, `AddBudgetSheet`) защищены от переполнения экрана при появлении ошибки и клавиатуры через `SingleChildScrollView`. В `AddTransactionSheet` прокручивается только форма (`Flexible` + `SingleChildScrollView`), а кнопка сохранения (`add_transaction_submit`) закреплена внизу листа вне прокрутки и поднимается над клавиатурой вместе с листом (`KeyboardInsetPadding` по `viewInsets.bottom`). Производительность при выезде клавиатуры: `MainShell` обёрнут в `KeyboardInsetsIsolation` (вкладки и навбар со стеклом не перестраиваются на каждом кадре анимации), форма листа — в `RepaintBoundary` (сужение области прокрутки не перерисовывает поля и чипсы), ввод суммы перестраивает лист только для сброса ошибки, а подсказку курса `TransactionAmountField` обновляет сам через `ValueListenableBuilder` контроллера.

- **Декомпозиция крупных экранов и полировка UI/UX**:
  - `WelcomeSetupScreen`: экраны онбординга (выбор языка и валюты) выполнены в цельном виде без отдельного верхнего хэдера/AppBar; блок заголовка и описания выбора языка зафиксирован по высоте (`SizedBox(height: 120)`), а кнопки выбора отделены комфортным отступом (`SizedBox(height: 40)`), что полностью исключает «скачки» кнопок вверх-вниз при смене языка и переносе строк; кнопка возврата назад на шаге валюты выровнена по левому краю экрана. При первом запуске приложение проверяет статус онбординга синхронно (`PreferencesService.isOnboardingCompletedSync`) и открывает `WelcomeSetupScreen` сразу в качестве корневого экрана (`routes['/']`), исключая предварительное мелькание или показ главного экрана.
  - `DashboardScreen`: декомпозирован на `GuestModeBanner`, `DayGroupWidget`, `TransactionItemTile` (директория `lib/widgets/dashboard/`).
    - **Выбор периода**: компактный `PeriodSwitcher` («‹ Октябрь ›», год показывается только для нетекущего года) стоит над `BalanceCard`. Стрелки листают месяцы через границу года, тап по подписи открывает `PeriodPickerSheet` (год со стрелками и сетка 12 месяцев). Период общий для вкладок «Баланс», «Финансы» и «Аналитика» — `SelectedPeriodService.periodNotifier`; при запуске всегда текущий месяц.
    - Дашборд и «Бюджет» перечитывают данные по `periodNotifier`, `CurrencyFormatter.currencyNotifier` и `LocalDbService.transactionsChanged` (операция сохранена/удалена с любой вкладки, а также завершённая загрузка изменений с сервера — один сигнал на загрузку, при 304 сигнала нет). Отдельные записи синхронизации сигнал не подают, чтобы не сбрасывать прокрутку списков.
    - Добавлен лаконичный заголовок «Баланс» по центру в AppBar; цвет фона AppBar и экрана строго синхронизированы (`colorScheme.surface`, `surfaceTintColor: transparent`).
    - Тень виджета `BalanceCard` уменьшена во избежание визуального наложения на расположенный ниже `BudgetPeriodSelector`.
    - Механика `CustomPullToRefresh` (Liquid Glass / Material 3): контент экрана (`BalanceCard`, `BudgetExpenseRatioCard` и списки) зафиксирован на месте и не съезжает вниз при оверскролле, а индикатор обновления отображается в виде плавающей стеклянной капсулы (Floating Pill) с прогрессом и спиннером непосредственно под `LiquidGlassAppBar`.
    - `TransactionItemTile`: поверхность строки транзакции сделана непрозрачной (`tileBgColor`), исключая просвечивание красной подложки удаления при анимации свайпа.
    - **Лента операций**: плоский список по дням. `DayGroupWidget` — заголовок с датой («Сегодня, …») и итогом дня (доходы минус расходы в базовой валюте, `effectiveBaseAmount` — сходится с карточкой месяца) и карточка со строками. `TransactionItemTile`: иконка и цвет категории (`CategoryStyle`), заголовок — описание (без описания — название категории), подпись — категория, справа сумма в валюте чека и «≈ сумма» в базовой валюте для иностранной валюты; описание — до двух строк; свайп влево удаляет; тап открывает `TransactionDetailsSheet` — карточку «только для чтения» (полное описание с выделением текста, категория, дата и время, для иностранной валюты — сумма чека и пересчёт) с кнопками «Редактировать» (`AddTransactionSheet`) и «Удалить»; подсказка свайпа — на первой строке первого дня.
    - **Режим «По категориям»** (`DashboardViewSwitcher`, `DashboardViewMode`): итоги категорий **за весь месяц** без пагинации (`CategoryMonthSummary.fromTransactions`, сортировка по модулю итога), карточка `CategoryMonthGroup` раскрывается (`AnimatedSize`, без `ExpansionTile`) в строки `TransactionItemTile(showDate: true)` — без иконки категории, с отступом 56 px под текст заголовка группы: день операции, под ним описание (если есть), сумма справа. В режиме «По дням» строка показывает категорию и под ней описание одной строкой (`AppFontSize.hint`, `colorScheme.outline`); без описания — только категория по центру. В `BalanceCard` «Доход»/«Расход» — диагональные стрелки (`south_west`/`north_east`) на подложках `AppColors.incomeOnBrand`/`expenseOnBrand`. Режим хранится в состоянии экрана, по умолчанию «По дням».
    - `BalanceCard` подписан «Итог месяца» (`month_total`): это доходы минус расходы выбранного месяца, а не накопленный остаток.
    - Суммы на экране (`CurrencyFormatter.formatText`) выводятся с типографским минусом «−» и моноширинными цифрами (`FontFeature.tabularFigures`); `format` для CSV/ввода не меняется.
  - `BudgetsScreen` (вкладка «Бюджет», ранее «Финансы»/«Лимиты»): `PeriodSwitcher`, `MonthBudgetCard`, `BudgetsSectionHeader`, список `BudgetItemCard`. Расходы по категориям считаются одним проходом (`getCategoryExpensesForPeriod`) и используются и карточкой месяца, и карточками лимитов.
    - **`MonthBudgetCard`** (бирюзовая карточка в стиле `BalanceCard`) по `MonthBudgetSummary`: текущий месяц — «Можно тратить в день» (остаток лимитов / дни до конца месяца включая сегодня) и «Осталось N дней» (ICU-плюрализация); перерасход — сумма перерасхода; прошлый месяц — «Итог по лимитам»; будущий — «Запланировано». Шкала потраченного и плашки «Лимиты / Потрачено / Осталось (Перерасход)». В расчёт входят только траты категорий с лимитом. Без лимитов — текст `no_budgets_subtitle` и кнопка «Добавить лимит» (отдельного пустого пузыря нет).
    - **`BudgetItemCard`**: иконка и цвет категории, главная строка — остаток или «Превышен на …», шкала с порогами цвета (`progressColorFor`: < 75% — основной, 75–100% — янтарный, > 100% — мягкий оранжевый), подпись «потрачено из лимита» и процент.
    - Кольцо структуры расходов (`BudgetExpenseRatioCard`) перенесено на «Аналитику».
  - `AddTransactionSheet` & `AddBudgetSheet`:
    - `AddTransactionSheet` декомпозирован на `TransactionTypeToggle`, `TransactionAmountField`, `TransactionDateSelector`, `CategoryChipsSelector` (`lib/widgets/transaction/`). День операции выбирается чипами «Сегодня» / «Вчера» / календарь (`showDatePicker`, не позже сегодняшнего дня); время берётся текущее для новой записи и исходное при редактировании, чтобы не ломать порядок операций внутри дня. Категория выбирается в один тап из чипов с иконками и цветами `CategoryGroupWidget` (`CategoryChipsSelector`): видно не больше 5 категорий — сначала частые за 90 дней (`LocalDbService.getFrequentCategories`), затем остальные — и чип «Ещё», открывающий `CategoryPickerSheet` со всеми категориями (поиск по названию при списке длиннее 15). Выбранная категория всегда видна в ряду; высота формы не растёт с числом категорий. Поле суммы новой операции получает фокус сразу при открытии. Подсказка пересчёта курса локализована (`rate_updated_on`, `rate_approximate`).
    - В `AddBudgetSheet` поле ввода суммы лимита расположено первым перед выбором категории.
    - Поле «Описание» настроено на ввод с заглавной первой буквы (`textCapitalization: TextCapitalization.sentences`).
    - Поле ввода суммы бюджета унифицировано с транзакциями: отображает краткую метку «Сумма» без валюты в скобках.
  - `ProfileScreen`: декомпозирован на `ProfileHeader`, `ProfileSyncCard`, `ProfileSettingsCard`, `ProfileDataCard`, `ProfileAppVersion`, `CurrencyPickerSheet`, `LanguagePickerSheet` (`lib/widgets/profile/`).
  - **Выгрузка отчётов (`ReportExportAction` → `ReportExportSheet`)**: кнопка «Отчёт» (в стиле «Войти» дашборда) в шапке вкладки «Аналитика» открывает лист с выбором периода (месяц/год из селектора экрана или свой диапазон через `showDateRangePicker`) и формата (PDF/CSV). Данные берутся из локальной ObjectBox (`LocalDbService.getTransactionsInRange`), файл формируется на устройстве, бэкенд не используется; две кнопки: «Сохранить» (`ReportDeliveryMode.save`: системный диалог выбора места через `file_picker.saveFile` с байтами — SAF на Android, «Файлы» на iOS, разрешения на хранилище не нужны; отмена диалога возвращает форму в `idle` без ошибки) и «Поделиться» (`ReportDeliveryMode.share`: системное меню, на iPad передаётся `sharePositionOrigin`). CSV: UTF-8 с BOM; для `ru/kk/uz` разделитель `;` и десятичная запятая (ожидание Excel), для `en` — `,` и `.`; описания, начинающиеся с `= + - @`, экранируются апострофом (CSV-инъекция). PDF: сводка, расходы по категориям, выполнение лимитов (только за месяцы, целиком входящие в период), таблица операций; суммы с кодом валюты, лимит страниц `MultiPage` увеличен до 5000. Суммы приводятся к базовой валюте аккаунта. Временные файлы режима «Поделиться» удаляются при следующей выгрузке (сразу после «Поделиться» удалять нельзя — целевое приложение читает файл позже).
  - **Тарифы и доступ к функциям (`EntitlementService`)**: платные функции перечислены в `AppFeature` (сейчас `reportExport`). `EntitlementService.instance.isEnabled(feature)` до подключения монетизации всегда возвращает `true`; при подключении биллинга достаточно заменить реализацию проверкой подписки. Бесплатный тариф: локальный функционал и инфографика на экране «Финансы». `ReportExportCubit` при отказе переходит в `ReportExportStatus.locked` (UI показывает предупреждение; сюда же подключается paywall).
  - `ProfileDataCard`: раздел «Данные» в профиле (виден всегда). Пункт «Удаление аккаунта и данных» с иконкой и подзаголовком-пояснением (справка, а не само удаление) открывает во внешнем браузере публичную страницу бэкенда `/delete-account?lang=<код языка>`. Само удаление остаётся кнопкой «Удалить аккаунт» внизу профиля. При ошибке открытия показывается тост `open_link_error`.
  - **Юридические ссылки (`lib/config/legal_links.dart`)**: `LegalLinks.url(LegalPage, languageCode)` строит URL страниц бэкенда `/terms`, `/privacy`, `/delete-account` от origin `EnvironmentConfig.baseUrl` (без `/api/v1`): release ведёт на прод, debug/local — на выбранный бэкенд (например, `http://10.0.2.2:8000`). Используется в `AuthScreen` («Условия использования», «Политика конфиденциальности») и в `ProfileDataCard`. Тексты хранятся и обновляются на бэкенде; в ARB ссылок нет.
  - `UserAvatar` (`lib/widgets/user_avatar.dart`): переиспользуемый отказоустойчивый виджет аватара пользователя с `Image.network`, `errorBuilder` и `loadingBuilder`. Исключает необработанные `SocketException` при сбоях сети/DNS (например, для аватаров Google `lh3.googleusercontent.com`) и плавно переключается на инициалы или иконку.
  - `InsightsScreen`: в шапке `ReportExportAction` (месяц берётся из `SelectedPeriodService.periodNotifier`); один прокручиваемый список, как на других вкладках: `PeriodSwitcher`, `ExpenseStructureSection` (кольцо `BudgetExpenseRatioCard` по локальным данным месяца; сама перечитывает данные при смене месяца/валюты и после сохранения операций; пустой месяц скрывается), затем AI-советы по состоянию кубита (`_InsightsBody`). Гость (`InsightsUnauthenticated`) видит карточку с подсказкой войти в аккаунт. Декоративный баннер «Умный анализ…» убран; подписи кольца локализованы через ARB (`structure_*`, включая казахский), бейдж процента показывается только при перерасходе дохода. Генерация AI — платный запрос к LLM, поэтому `InsightsCubit` следует правилам: будущий месяц и месяц без локальных операций — `InsightsUnavailable` (`InsightsUnavailableCard`) без запроса; текущий месяц — запрос с генерацией (бэкенд отдаёт сохранённый отчёт, пока новых операций месяца меньше 5); прошлые месяцы и смена валюты/языка — `GET /insights?generate=false`: сохранённый отчёт показывается автоматически, при `state=not_generated` — `InsightsAwaitingRequest` с кнопкой «Сформировать анализ» (`InsightsGenerateCard`); pull-to-refresh — `loadInsights(force: true)`. Ответ `state=no_data` → `InsightsUnavailable`, `quota_exceeded` → сообщение о лимите (не кэшируется), `busy` (сбой AI-провайдера) → `InsightsError` с карточками «Наши умные помощники сейчас очень заняты…» (не кэшируется, следующий заход запросит отчёт снова). Полученные отчёты кэшируются на сессию (ключ — период, валюта, язык; очищается при выходе). Экран применяет общий период к кубиту только при активной вкладке; анимированный лоадер генерации `AiSparklesLoader`; единый Graceful Fallback при ошибках бэкенда («Наши умные помощники сейчас очень заняты»); оптимизирован для работы внутри `IndexedStack` (`MainShell` передает `isActive: _currentIndex == 2`), выполняет ленивую загрузку строго при первом открытии вкладки, смене периода пользователем (`setPeriod`) или явном Pull-to-Refresh, игнорируя фоновые смены языка/валюты до первого входа.
  - `AuthScreen`: устранен отдельный AppBar/хэдер, экран выполнен в виде целостного холста с верхним радиальным свечением темы, центрированным стеклянным медальоном, комфортной типографикой и аккуратной встроенной кнопкой возврата назад (при наличии стека навигации) по аналогии с `WelcomeSetupScreen` и `WelcomeLanguageSheet`.
  - Методы `_buildX` заменены на независимые StatelessWidget / StatefulWidget с чистым контрактом передачи параметров и колбэков.

- **Жизненный цикл провайдеров в `main.dart`**:
  - `BlocProvider<AuthCubit>` вынесен на самый верхний уровень над `ValueListenableBuilder` темы и языка, исключая пересоздание `AuthCubit` и сброс его подписок при динамическом переключении настроек пользователем.

- **Адаптивная ориентация устройств**:
  - В `main.dart` перед установкой `SystemChrome.setPreferredOrientations` проверяется размер экрана: для планшетов и iPad (`shortestSide >= 600`) разрешены все 4 ориентации (`portraitUp`, `portraitDown`, `landscapeLeft`, `landscapeRight`) для соответствия гайдлайнам App Store/Google Play, в то время как телефоны работают в портретном режиме.

- **Скрытое Debug-меню (`DebugMenuScreen`)**:
  - Активируется 5 тапами по плашке версии приложения в профиле (`ProfileAppVersion`).
  - Добавлен `Timer` на 2 секунды для сброса счётчика тапов при паузе.
  - Тексты и элементы меню отладки полностью интернационализированы (`AppLocalizations`) на русском, узбекском, казахском и английском языках, цвета синхронизированы с текущей темой.

- **Мультиязычность и локализация (Localization & Regionalization)**:
  - **Поддерживаемые языки**: Русский (`ru`), Узбекский (`uz`), Казахский (`kk`), Английский (`en`).
  - Локализация построена на базе `flutter_localizations` и генератора Flutter Gen L10n (`lib/l10n/app_*.arb`).
  - **Казахская локализация (`app_kk.arb`)**: Полный и корректный перевод всех ключей интерфейса, финансовой аналитики, системных ошибок, категорий расходов/доходов и меню отладки.
  - **Правила форматирования (`LanguageManager`)**:
    - Форматирование даты (`formatDayMonth`): `'$day $monthGen'` (например, «14 қазан»).
    - Форматирование даты и времени (`formatDateTime`): для другого года — `'${date.year} ж. $dayMonth, $timeStr'` (например, «2024 ж. 14 қазан, 12:00»).
    - Форматирование счетчика операций (`formatOperationsCount`): `'$count операция'` (в казахском языке после числительных существительное используется в единственном числе).
  - **Автовыбор валюты на онбординге**: При выборе `AppLanguage.kk` в `WelcomeSetupScreen` и `WelcomeLanguageSheet` базовой валютой автоматически назначается `Currency.kzt` (Казахстанский тенге), если пользователь еще не менял валюту вручную.
  - Реактивное переключение через `LanguageManager.languageNotifier` без перезапуска приложения с сохранением в `PreferencesService`.

- **Мультивалютная архитектура (Clean Multi-Currency Architecture)**:
  - **Поддерживаемые валюты и прекращение поддержки RUB**:
    - В приложении поддерживаются 4 валюты: `USD` (доллар США), `EUR` (евро), `UZS` (узбекский сум), `KZT` (казахстанский тенге).
    - Базовая валюта по умолчанию: `USD` (для пользователей узбекского языка — `UZS`, казахского языка — `KZT`).
    - Поддержка `RUB` (российский рубль) полностью исключена из перечисления `Currency`, резервных курсов `_fallbackRatesToUsd` и файлов локализации.
    - **Обратная совместимость и миграция**:
      - `CurrencyFormatter.loadSavedCurrency()` при обнаружении отсутствующего или устаревшего кода (`RUB`) в `PreferencesService` безопасно переключает валюту на `USD` и перезаписывает настройку в хранилище.
      - В `LocalDbService` метод `_migrateLegacyTransactions()` автоматически мигрирует локальные транзакции с `currencyCode == 'RUB'` в текущую базовую валюту аккаунта (`CurrencyFormatter.currentCurrency.code`).
      - `Transaction.currency` в `local_db_models.dart` через `orElse` гарантирует возврат `CurrencyFormatter.currentCurrency` при отсутствии кода в перечислении.
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
- **Аутентификация и синхронизация профиля соцсетей (OAuth & Profile Sync)**:
  - **Безопасная инициализация Google Sign-In**: Вызов `GoogleSignIn.instance.initialize` централизован с использованием `ApiConfig.googleServerClientId`. При выходе из аккаунта (`AuthApiService.clearAllUserData`) клиент гарантирует инициализацию перед вызовом `GoogleSignIn.instance.signOut()`, предотвращая сбои `StateError` при сбросе сессии на повторных запусках.
  - **Клиентская синхронизация аватара и имени**: При авторизации через Google (`AuthScreen`) клиент извлекает актуальный `photoUrl` и `displayName` из возвращенного `GoogleSignInAccount`. Если аватар отсутствует в ответе бэкенда (например, из-за часового кэширования OIDC ID-токена Google на устройстве или задержки распространения клейма `picture`), клиент автоматически отправляет актуальные данные на сервер через `updateUserProfile(avatarUrl: googlePhoto)`.
  - **Реактивное обновление состояния (`AuthCubit`)**: Состояние `Authenticated` хранит актуальный `avatarUrl`. При обновлении аватара или имени `AuthApiService` уведомляет стрим авторизации, инициируя реактивное обновление интерфейса (в `MainShell`, `ProfileHeader`, `DashboardScreen`).
- **Безопасность релизного бандла и конфигурация сборки (Release Bundle & Environment Security)**:
  - **Исключение `.env` из ресурсов сборки**: Строка `- .env` исключена из секции `flutter -> assets` в `pubspec.yaml`, предотвращая попадание файла конфигурации в открытом виде в `flutter_assets/.env` внутри релизных `.aab`/`.apk`.
  - **Приоритет `--dart-define`**: В `EnvironmentConfig` параметры API и дефолтное окружение считываются через `--dart-define` / `--dart-define-from-file` с наивысшим приоритетом. Попытка загрузки `.env` в debug/profile изолирована блоком `try-catch` в `lib/main.dart` и не приводит к сбою приложения при отсутствии ассета.
  - **Выравнивание Android namespace и пакетов**: В `android/app/build.gradle.kts` параметр `namespace` приведен в соответствие с `applicationId`: `com.getbalanceai.mobile`. Файл `MainActivity.kt` перемещен в пакет `com.getbalanceai.mobile`, устаревший пакет `com.example.finance_app_mobile` полностью удален.
  - **Унификация названия приложения**: Заголовок `MaterialApp` в `lib/main.dart` приведен к единому значению `'GetBalance AI'`, синхронизированному с `AndroidManifest.xml` (`android:label`) и `Info.plist` (`CFBundleDisplayName`, `CFBundleName`).

