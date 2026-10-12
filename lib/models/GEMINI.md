# Правила моделей (lib/models/)

* Денежные поля (`amount`, `limit_amount`, `spent`, `remaining`; на бэкенде `Decimal(12,2)`) — только `parseAmount(json[...])`, никаких `as double`/`as num` (API может прислать `"150.50"`).
* Даты: отправка `dt.toUtc().toIso8601String()`, приём `DateTime.parse(s).toLocal()`.
* Списки → `PaginatedResponse<T>` (`items`, `total`, `limit`, `offset`).
* Локализация enum/моделей (`getLocalizedName()`) — через `LanguageManager.l10n`, без `BuildContext` и без хардкодных Map-переводов.
* `@Entity()`: `@Id() int id = 0`; `String? serverId` (UUID сервера); `@Index()` на полях фильтрации/сортировки (`serverId`, `date`, `category`, `userId`); поля синхронизации `isSynced`, `updatedAt`.
* После изменения `@Entity()` — кодогенерация (см. корневой GEMINI.md, шаг 5); `objectbox-model.json` хранит стабильные ID схемы и коммитится.
