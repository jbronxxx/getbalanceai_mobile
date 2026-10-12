# Ревью изменений `main` за 10–12.10 (PR #39 – #50)

Охват: security/auth fixes, perf, income categories, UI refactor, иконки/splash, мультивалютность, Liquid Glass UI.
Приоритеты: **P0** — потеря данных/краш, **P1** — заметный баг/регрессия, **P2** — качество/долг.

---

## A. Логика и данные

### [x] A1 (P0). ETag сохраняется до окончания пагинации → потеря данных
[sync_service.dart:288-292](file:///Users/user/getbalanceai_mobile/lib/services/sync_service.dart#L288-L292)
- ETag пишется в storage сразу после 1-й страницы. Если страница 2..N упала, следующий sync получит `304` и остальные страницы не догрузятся никогда.
- **Фикс:** сохранять ETag только после успешной загрузки всех страниц (и `hasMore == false`).

### [x] A2 (P0). Reconcile по неполному списку удаляет локальные транзакции
[sync_service.dart:333-336](file:///Users/user/getbalanceai_mobile/lib/services/sync_service.dart#L333-L336), [local_db_service.dart:302](file:///Users/user/getbalanceai_mobile/lib/services/local_db_service.dart#L302)
- При достижении `maxPages` с `hasMore == true` (или `nextItems.isEmpty` при `hasMore`) возвращается частичный список, а `reconcileTransactions` удаляет все синхронизированные записи, которых нет в нём.
- **Фикс:** при неполной выгрузке возвращать флаг `isComplete=false` и в этом случае делать только upsert, без удаления; ETag не сохранять.

### [x] A3 (P1). ETag не привязан к пользователю/локальной БД
[sync_service.dart:39-47](file:///Users/user/getbalanceai_mobile/lib/services/sync_service.dart#L39-L47)
- Если локальная БД очищена (переустановка с восстановлением Keychain на iOS, сброс данных, смена окружения в debug-меню), сервер вернёт `304` и список останется пустым. `FlutterSecureStorage` на iOS переживает удаление приложения.
- **Фикс:** хранить ETag с ключом `userId+env`; если локальная выборка пуста — не отправлять `If-None-Match`; очищать ETag при смене окружения.

### [x] A4 (P1). Нулевой/битый курс молча превращается в 1.0
[currency_exchange_service.dart:92-102, 159-168](file:///Users/user/getbalanceai_mobile/lib/services/currency_exchange_service.dart#L92-L168)
- `rates[code] = 0` или отрицательное значение принимается без валидации; `getRate` при `fromRate <= 0` возвращает `1.0` → 1 UZS = 1 USD в балансе.
- **Фикс:** принимать только `val > 0 && val.isFinite`; иначе оставлять предыдущее значение и логировать `AppLogger.w`.

### [x] A5 (P1). Краш `CurrencyInputFormatter` на длинной вставке
[currency_formatter.dart](file:///Users/user/getbalanceai_mobile/lib/utils/currency_formatter.dart) — `int.parse(intPart)`
- Вставка строки из >19 цифр с ведущим нулём → `FormatException`.
- **Фикс:** убирать ведущие нули через `replaceFirst(RegExp(r'^0+(?=\d)'), '')`, ограничить длину целой части (`maxAmount.toStringAsFixed(0).length`).

### [x] A6 (P2). Нелокализованные исключения в сервисах
[sync_service.dart:52,113,127,173](file:///Users/user/getbalanceai_mobile/lib/services/sync_service.dart#L52) — `Exception('Не авторизован')`, `'Ошибка синхронизации: …'`.
- Строки уходят в UI для en/uz-пользователей. **Фикс:** типизированные исключения (`SyncException(code)`) + маппинг в `AppErrorHandler` через `AppLocalizations`.

### [x] A7 (P2). Десятичный разделитель захардкожен
`CurrencyFormatter.format` всегда `,` и пробел как разделитель тысяч. Для `en`/`USD` ожидается `$1,234.56`. Рассмотреть `NumberFormat.currency(locale: …)` из `intl`.

### [x] A8 (P2). Устаревшая вшитая таблица курсов
`_fallbackRatesToUsd` (RUB 96, UZS 12800) — показывать в UI пометку «курс приблизительный / обновлён {date}», если `lastUpdated == null` или старше 24 ч.

---

## B. Безопасность / приватность

### [x] B1 (P1). Fallback на сторонний `open.er-api.com`
[currency_exchange_service.dart:192](file:///Users/user/getbalanceai_mobile/lib/services/currency_exchange_service.dart#L192)
- Неконтролируемый третий сервис: утечка IP/факта использования, нет SLA, нет валидации диапазонов. Нужно упомянуть в Privacy Policy (App Store Privacy Nutrition) либо убрать и полагаться на бэкенд + кэш.
- Минимум: sanity-check (курс не изменился > чем в 2 раза относительно кэша).

### [x] B2 (P2). Отдельный `Dio` без интерцепторов
`CurrencyExchangeService._dio` не проходит через трассировку/логирование и общие таймауты/retry. Использовать общий клиент (без auth-заголовка для внешнего хоста).

---

## C. UI/UX (Liquid Glass)

### [x] C1 (P1). Регрессия доступности навбара и FAB
[liquid_glass_nav_bar.dart](file:///Users/user/getbalanceai_mobile/lib/widgets/liquid_glass_nav_bar.dart), [liquid_glass_fab.dart](file:///Users/user/getbalanceai_mobile/lib/widgets/liquid_glass_fab.dart)
- Material `NavigationBar` давал `Semantics(selected, button, "вкладка 1 из 4")`; `GestureDetector` — нет. FAB без `tooltip`/semantic label.
- **Фикс:** обернуть элемент в `Semantics(button: true, selected: isSelected, label: item.label)`, использовать `InkWell`/`InkResponse` для ripple и фокуса; FAB — параметр `tooltip` + `Tooltip`/`Semantics(label: l10n.add_transaction)`.
- Hit-area элемента ≈ 22+3+14+12 ≈ 51 dp — ок, но проверить при `textScaler` 1.3+ (лейбл 11sp обрезается ellipsis → добавить `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`).

### [x] C2 (P1). SnackBar/AppAlerts перекрываются плавающим навбаром
[main_shell.dart:88-128](file:///Users/user/getbalanceai_mobile/lib/screens/main_shell.dart#L88-L128)
- Навбар перенесён из `Scaffold.bottomNavigationBar` в `Stack` → Scaffold больше не знает о его высоте; SnackBar'ы вложенных Scaffold всплывают под стеклом.
- **Фикс:** экспортировать `LiquidGlassNavBar.totalHeight(context)` и задавать `SnackBarBehavior.floating` с `margin.bottom = totalHeight + 8` (или в `AppAlerts`).

### [x] C3 (P1). Магические отступы, продублированные в 3 экранах
`68.0`, `+6`, `16.0`, `SizedBox(height: 140)` в [dashboard_screen.dart:427-437](file:///Users/user/getbalanceai_mobile/lib/screens/dashboard_screen.dart#L427-L437), [budgets_screen.dart:218](file:///Users/user/getbalanceai_mobile/lib/screens/budgets_screen.dart#L218), [profile_screen.dart:297](file:///Users/user/getbalanceai_mobile/lib/screens/profile_screen.dart#L297).
- Любое изменение высоты навбара сломает FAB/последний элемент списка. **Фикс:** одна константа/хелпер в `LiquidGlassNavBar`, использовать `MediaQuery.paddingOf(context)` (меньше ребилдов, чем `MediaQuery.of`).

### [x] C4 (P1). Хардкод цветов вместо `colorScheme`
23 файла содержат `Color(0x…)` (полный список: `grep -rln "Color(0x" lib`). Критичные: `liquid_glass_nav_bar.dart` (`0xFF2DD4BF`, `0xFF141418`), `liquid_glass_fab.dart` (`0xFF0F766E`), `glass_container.dart`, `app_alerts.dart`.
- **Фикс:** вынести glass-токены в `ThemeExtension<GlassTheme>` в [app_theme.dart](file:///Users/user/getbalanceai_mobile/lib/theme/app_theme.dart) (surfaceTint, rim, shadow, accent), FAB — `colorScheme.primary/onPrimary`.

### [x] C5 (P2). Тень просвечивает сквозь полупрозрачное стекло
`BoxShadow` рисуется под всей площадью контейнера, а заливка 65–78 % альфы → внутри навбара/FAB виден грязный тёмный ореол (особенно в светлой теме). Использовать тень с меньшим `blurRadius` и смещением или `ShapeDecoration` + отдельный слой тени, обрезанный по внешнему контуру.

### [x] C6 (P2). Контраст неактивных пунктов
`onSurface @ 0.55` поверх полупрозрачного фона с произвольным контентом под ним — риск < 4.5:1 (WCAG AA) в светлой теме. Поднять до 0.70 или использовать `onSurfaceVariant`.

### [x] C7 (P2). Мёртвый код `GlassContainer`
[glass_container.dart](file:///Users/user/getbalanceai_mobile/lib/widgets/glass_container.dart) нигде не используется, при этом в `welcome_setup_screen.dart` (×3), `profile_screen.dart`, `app_alerts.dart` (×2) blur реализован вручную. Либо перевести эти места на `GlassContainer`, либо удалить.

### [x] C8 (P2). Нет состояния «нажато» у навбара
`AnimatedContainer` только по selected; нет pressed/ripple feedback, кроме haptic. Добавить scale 0.96 на tap-down (как у iOS 26 Liquid Glass).

---

## D. Производительность

### [ ] D1 (P1). Тяжёлый `BackdropFilter` (sigma 28) поверх скроллящегося списка
- Каждый кадр скролла пересчитывает blur во весь размер навбара; на Android low/mid-end (Impeller/Skia) — джанк.
- **Фикс:** снизить sigma до 16–20; обернуть навбар в `RepaintBoundary`; для Android < API 31 / при `MediaQuery.disableAnimations` — fallback на непрозрачную заливку без blur.

### [ ] D2 (P2). Все экраны пересоздаются при смене вкладки
`_getScreens(...)[_currentIndex]` + внешний `ValueListenableBuilder<Currency>` пересоздаёт список экранов на каждый rebuild; позиция скролла и состояние вкладок теряются. Рассмотреть `IndexedStack` (или `PageStorageKey` для скроллов) и перенести `ValueListenableBuilder` ниже.

---

## E. Тесты (добавить)
- [x] E1. `sync_service`: падение на 2-й странице → ETag не сохранён, локальные записи не удалены (A1, A2).
- [x] E2. `currency_exchange_service`: курс `0`, `-1`, `"abc"` игнорируются (A4).
- [x] E3. `CurrencyInputFormatter`: вставка `"000…0001"` (25 символов) без исключения (A5).
- [x] E4. Widget-тест `LiquidGlassNavBar`: `find.bySemanticsLabel` + `isSelected` (C1).

---

## F. Бэкенд — промт (getbalanceai_api)

```text
Нужны правки в getbalanceai_api для корректной работы мобильной синхронизации и мультивалютности:

1. GET /transactions (cursor-пагинация + ETag):
   - ETag должен вычисляться по ВСЕЙ коллекции пользователя (max(updated_at) + count + user_id),
     а не по содержимому первой страницы. Отдавать ETag только в ответе первой страницы (без cursor).
   - Запросы с `cursor` не должны отвечать 304 и не должны учитывать If-None-Match.
   - Включить user_id в ETag, чтобы смена аккаунта на устройстве не давала ложный 304.

2. GET /currency/rates (ApiConfig.currencyRates):
   - Формат: {"data": {"base": "USD", "rates": {...}, "updated_at": "<UTC ISO8601>"}}.
   - Валидировать курсы перед отдачей: только > 0 и конечные; при сбое провайдера отдавать
     последний валидный кэш и updated_at кэша, а не 0/null.
   - Кэшировать на сервере (Redis, TTL 1–6 ч), отдавать Cache-Control: public, max-age=3600.
   - Эндпоинт должен быть доступен без авторизации (гостевой режим) с rate limit по IP.

3. POST /sync:
   - Идемпотентность удалений: id из deleted_*_ids, которых уже нет, не должны давать ошибку.
   - В synced_transactions/synced_budgets возвращать client_id ↔ server id для каждого элемента
     в том же порядке, что и во входном массиве.

Покрыть тестами: ETag стабилен между страницами, 304 только для первой страницы,
rates без нулей при падении провайдера, повторная отправка удаления → 200.
```

---

## Чек после исправлений
```bash
fvm flutter test
```
