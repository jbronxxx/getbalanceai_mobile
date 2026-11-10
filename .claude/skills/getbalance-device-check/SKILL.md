---
name: getbalance-device-check
description: Проверка задачи GetBalance на телефоне пользователя после того, как код готов (format/analyze/test зелёные): просьба подключить телефон, установка release, проверка на локальном бэкенде через debug-сборку с релизной подписью, снятие и восстановление данных приложения. Использовать в конце каждой задачи getbalanceai_mobile, где нужна проверка на устройстве или установка release.
---

# Проверка на телефоне — GetBalance

На телефоне пользователя (Galaxy S24) стоит release с prod API и его настоящие данные. Любое действие может изменить реальные записи и уйти на сервер.

## 1. Когда задача готова

1. Прогнать проверки из `CLAUDE.md` (format, analyze, test) и описать результаты.
2. **Остановиться** и одним сообщением:
   - попросить: «Задача готова — подключите телефон для тестирования и установки»;
   - спросить: «Можно ли менять данные на телефоне (создавать/править/удалять записи) для проверок?».
   Разрешение действует только на текущую задачу; в следующей — спросить снова.
3. Без явного разрешения **не** проверять `adb devices`/`adb mdns`, не ждать подключения в цикле и не запускать эмуляторы.
4. Дальше — только после того, как пользователь напишет, что телефон подключён.

## 2. Общие правила на устройстве

* `adb devices -l` — ровно одно устройство; все команды с `-s $S`. Переменные ниже: `S=<serial>`, `P=com.getbalanceai.mobile`, `D=<scratchpad>`.
* Тапать только по свежему скриншоту: `adb -s $S exec-out screencap -p > $D/s.png && sips -Z 1000 $D/s.png --out $D/s1.png`, координаты × 1080/ширину превью. После переключения вкладок прокрутка сохраняется — сначала скриншот.
* Предпочитать безопасные действия: вертикальные свайпы, нижняя навигация, перезапуск приложения (`am force-stop` + `monkey -p $P -c android.intent.category.LAUNCHER 1`).
* Данные менять только при «да» на вопрос из шага 1.2. Без него — проверки без изменений.
* На «Аналитике» не открывать текущий месяц без нужды — платная генерация ИИ.
* `adb shell input text` не вводит кириллицу — названия латиницей. Тост с «Отменить» живёт 5 секунд: действие и тап по «Отменить» — в одной команде.
* Ошибки: `adb -s $S logcat -d | grep -E "AndroidRuntime|FATAL|flutter"` (перед запуском `logcat -c`).
* Если что-то случайно изменилось — сразу проверить и честно сообщить.

## 3. Установка release (проверка без локального бэкенда)

1. Сверить подпись установленной сборки и новой:
   ```bash
   BT=$(ls -d ~/Library/Android/sdk/build-tools/* | tail -1)
   adb -s $S pull "$(adb -s $S shell pm path $P | grep base | sed 's/package://' | tr -d '\r')" $D/installed.apk
   fvm flutter build apk --release --dart-define-from-file=.env
   $BT/apksigner verify --print-certs $D/installed.apk | grep SHA-256
   $BT/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk | grep SHA-256
   ```
   При несовпадении приложение **не удалять** — спросить пользователя.
2. `adb -s $S install -r build/app/outputs/flutter-apk/app-release.apk`.

## 4. Проверка на локальном бэкенде

Нужна, когда задача меняет API или проверка требует менять данные. Бэкенд поднимается скиллом `getbalance-local-backend` в `../getbalanceai_api` (ветка задачи, миграции применены, `/health` = 200).

### 4.1. Debug-сборка с релизной подписью и локальным API
Релизная подпись нужна, чтобы debug встал поверх release без удаления (данные сохраняются) и работал вход через Google (SHA-1 зарегистрирован для релизного ключа). Debug-сборка даёт `run-as` для снятия данных.

1. Временно в `android/app/build.gradle.kts` внутри `buildTypes {` перед `release {`:
   ```kotlin
   debug {
       signingConfig = signingConfigs.getByName("release")
   }
   ```
2. Собрать и **сразу откатить** gradle:
   ```bash
   fvm flutter build apk --debug --dart-define-from-file=.env \
     --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1 --dart-define=DEFAULT_ENVIRONMENT=local
   git checkout android/app/build.gradle.kts && git status --short android/
   ```

### 4.2. Установка и снятие копии данных (до первого запуска)
```bash
adb -s $S shell am force-stop $P
adb -s $S install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s $S exec-out "run-as $P tar cf - --exclude=cache --exclude=code_cache ." > $D/appdata.tar
tar tf $D/appdata.tar | grep -v '/$' | sort > $D/bak.txt; wc -l < $D/bak.txt   # не пусто, размер копии — десятки МБ
```
Копию не удалять до восстановления в 4.6.

### 4.3. Временное отключение блокировки приложения
Блокировка (отпечаток/PIN) мешает запуску через adb. Отключить в копии настроек на телефоне — вернётся при восстановлении копии:
```bash
adb -s $S shell "run-as $P sed -i 's/privacy_app_lock_enabled\" value=\"true/privacy_app_lock_enabled\" value=\"false/' shared_prefs/FlutterSharedPreferences.xml"
adb -s $S shell "run-as $P grep privacy_app_lock shared_prefs/FlutterSharedPreferences.xml"   # value="false"
```

### 4.4. Запуск с локальным API
```bash
adb -s $S reverse tcp:8000 tcp:8000
adb -s $S shell svc power stayon usb
adb -s $S logcat -c
adb -s $S shell monkey -p $P -c android.intent.category.LAUNCHER 1
```

### 4.5. Вход
* Аккаунт — **e.makarov** (Google-аккаунт на телефоне): «Войти» → Google → выбрать e.makarov в списке аккаунтов (по скриншоту).
* QA-аккаунт (qa.hamkor…) — **только с отдельного разрешения** пользователя в этой задаче.
* Гостевые записи после входа уходят на локальный бэкенд, на prod — нет; копия 4.2 вернёт всё как было.
* Состояние на сервере сверять через psql (см. скилл бэкенда), а не только по экрану.

### 4.6. Очистка и возврат release
1. Удалить тестовые данные с локального бэкенда — только созданное в этой проверке (по `id` или описанию из psql), не трогая прочие записи e.makarov. Временные правки бэкенда (лимиты и т.п.) откатить: `git checkout <файл>` + `docker compose restart api`.
2. Восстановить данные приложения (debug ещё установлен — нужен `run-as`):
   ```bash
   adb -s $S shell am force-stop $P
   adb -s $S shell "run-as $P find . -path ./cache -prune -o -path ./code_cache -prune -o -type f -print" | sort > $D/now.txt
   for f in $(comm -23 $D/now.txt $D/bak.txt); do adb -s $S shell "run-as $P rm -f '$f'"; done   # новые файлы
   adb -s $S exec-in "run-as $P tar xf -" < $D/appdata.tar
   ```
3. Сверить с копией: список файлов совпадает, содержимое — побайтно:
   ```bash
   adb -s $S shell "run-as $P find . -path ./cache -prune -o -path ./code_cache -prune -o -type f -print" | sort > $D/now.txt
   diff $D/now.txt $D/bak.txt && echo SAME_FILES
   adb -s $S exec-out "run-as $P tar cf - --exclude=cache --exclude=code_cache ." > $D/after.tar
   for f in $(cat $D/bak.txt); do [ "$(tar xOf $D/appdata.tar "$f" | md5)" = "$(tar xOf $D/after.tar "$f" | md5)" ] || echo "DIFF $f"; done
   ```
   Есть `DIFF` — не продолжать, разобраться и сообщить.
4. Вернуть release и устройство:
   ```bash
   fvm flutter build apk --release --dart-define-from-file=.env
   adb -s $S install -r build/app/outputs/flutter-apk/app-release.apk
   adb -s $S reverse --remove tcp:8000
   adb -s $S shell svc power stayon false
   adb -s $S shell "run-as $P ls" 2>&1 | head -1   # "not debuggable" — стоит release
   ```
5. `git status` приложения — без правки `build.gradle.kts`.

## 5. Итог
Что проверено вживую, что нет и почему; данные восстановлены (SAME_FILES, без DIFF), release установлен. Результаты записать в чек-лист задачи.
