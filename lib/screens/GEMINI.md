# Правила UI (lib/screens/, lib/widgets/)

* Только отображение (Material 3) и передача действий в Cubit. Никаких вызовов Dio/синхронизации напрямую.
* Цвета и шрифты — только `Theme.of(context).colorScheme` / `textTheme` (никаких `Colors.*`, `0xFF...`) — важно для Dark Mode.
* Строки — только `AppLocalizations.of(context)`.
* `BlocConsumer`: рендер в `builder`; навигация, `SnackBar`, `AppAlerts` — только в `listener`.
* `BlocProvider(create: (_) => MyCubit()..init())`; не размещать внутри `ValueListenableBuilder`/билдеров темы/локали (пересоздание кубита).
* Экран ≤ 300–400 строк; секции — отдельные `StatelessWidget`/`StatefulWidget`, а не методы `_buildX()`.
* После `await` перед `setState()`/`context`: `if (!mounted) return;`.
* 429 → `AppAlerts.showRateLimitDialog(context, retryAfter: ...)`; 503 → `ServiceUnavailableScreen` или `AppAlerts.showServiceUnavailableDialog`.
* Каждый экран имеет состояния loading (индикатор/skeleton) и empty (с подсказкой).
