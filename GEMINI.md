# Регламент разработки Finance App Mobile (Flutter)

Production-grade финансовое приложение iOS/Android. Источник правды: [ARCHITECTURE.md](ARCHITECTURE.md), [README.md](README.md), [REVIEW_CHECKLIST.md](REVIEW_CHECKLIST.md). Локальные правила слоёв: `lib/screens/`, `lib/cubits/`, `lib/services/`, `lib/models/`, `test/` (`GEMINI.md` в каждой).

## 1. Глобальные правила кода
* Логирование **только** через `AppLogger` (Talker): `AppLogger.e('msg', error, stackTrace)`. `print()`/`debugPrint()` в `lib/` и `test/` — критическая ошибка.
* Без ИИ-меток (`// AI generated`, `// Temporary fix`, `// TODO for AI`), закомментированного кода, временных файлов. Комментарии — кратко, на русском, по предметной области.
* Глобальные поля (напр. `LanguageManager.l10n`) — ленивая инициализация/fallback (`lookupAppLocalizations(...)`), без небезопасных `late` (исключить `LateInitializationError` в тестах).
* Без затенения имён: параметры не должны совпадать с методами класса (`static void e(msg, [error]) => error(...)` — баг). Делегировать напрямую (`talker.error(...)`).
* Никто, кроме точки входа, не импортирует `main.dart`. Синглтоны — `ApiService.instance`, `LocalDbService.instance`.
* Чистый код сразу: `flutter_lints` (`analysis_options.yaml`), `dart format`, без unused imports/dead code/deprecated API.

## 2. Слои
Screens/Widgets (UI M3, без логики) → Cubits (состояние, без `BuildContext`) → Services (Dio, ObjectBox, SecureStorage) → Models (DTO, `@Entity()`). Config/Utils: `EnvironmentConfig`, `AppLogger`.

## 3. Флоу задачи
1. **Ветка** от свежего `main`: `git checkout main && git pull origin main && git checkout -b <type>/<name>`; типы: `feat|fix|refactor|test|docs|chore`. Коммиты в `main` запрещены.
2. **Код** по границам слоёв и локальным правилам.
3. **Тесты**: обновить/добавить unit, `bloc_test`, widget-тесты; happy path + негатив (валидация, 401/403/404, 429, 503, офлайн).
4. **Проверки запускает только пользователь.** Агенту запрещено самому выполнять `dart format`, `flutter analyze`, `flutter test`, `build_runner`, `pub get` (включая MCP `analyze_files`/`pub`). В конце ответа выдать блок команд для ручного запуска (лишние убрать):
   ```bash
   fvm dart format lib test
   fvm flutter analyze
   fvm flutter test
   ```
5. **ObjectBox** (изменены `@Entity()`): добавить в блок команд `fvm flutter pub run build_runner build --delete-conflicting-outputs`; `lib/objectbox.g.dart` и `lib/objectbox-model.json` коммитятся.
6. **Зависимости** (изменены `pubspec.yaml`, `.env*`, `.fvmrc`): добавить в блок команд `fvm flutter pub get`.
7. **Ревью (Senior Reviewer)**:
   * ревью по диффу (grep `print(`/`debugPrint(` в `lib/` допустим); нет мусора, ИИ-меток, name shadowing;
   * границы слоёв, нет импорта `main.dart`, Cubit без `BuildContext`, сервисы декомпозированы (`AuthApiService`, `TransactionApiService`, `BudgetApiService`, `SyncService`), единый логгер;
   * безопасность: JWT в `FlutterSecureStorage`, секреты не логируются, нет цикла 401;
   * UI: цвета из `colorScheme`, строки из `AppLocalizations`, состояния loading/empty/429/503;
   * ресурсы: `StreamSubscription`/`CancelToken` закрыты в `close()`, `mounted`/`isClosed` проверяются;
   * тесты: моки платформ, ленивые fallback'и, SnackBar через `pump()` + `pump(500ms)`.
8. **Документация**: ARCHITECTURE.md (архитектура/модели/сервисы/контракты), README.md (`.env`, команды, фичи), REVIEW_CHECKLIST.md (закрытый техдолг).
9. **Git**: `git status` — без `build/`, `.dart_tool/`, `.idea/`, `.vscode/`, артефактов отладки.
10. **Бэкенд**: если нужны доработки API/контрактов — кратко перечислить их в конце ответа. Промт для бэкенда — только по запросу пользователя.
