# Правила сервисов (lib/services/)

* Без UI: не принимают `BuildContext`, ошибки — через исключения/типизированные ответы.
* Никогда не логировать пароли, refresh-токены, PII; заголовок `Authorization` маскируется.
* Доменная декомпозиция: `AuthApiService` (auth, JWT, профиль, удаление аккаунта), `TransactionApiService` (транзакции, категории, чеки), `BudgetApiService` (лимиты, бюджеты, аналитика), `SyncService` (синхронизация, коллизии). `ApiService` — тонкий фасад.
* `TracingInterceptor`: каждый запрос получает `X-Request-ID` (UUIDv4), ID пишется в логи ошибок для корреляции с бэкендом.
* 401: refresh ровно один раз через `Completer`-блокировку; повтор помечается `requestOptions.extra['retried'] = true`; `/auth/login|register|google|apple|refresh` исключены из перехвата.
* 429: читать `Retry-After` и передавать задержку в исключении. 503: переводить приложение в режим техобслуживания.
* ObjectBox: не использовать `box.getAll()` без необходимости — `box.query(...)` по `@Index()` полям.
* Удаления офлайн → tombstones в `PendingDeletionsStore`; очередь очищается только после успешного ответа API.
