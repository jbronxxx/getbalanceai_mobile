# GetBalance AI (getbalanceai_mobile)

Flutter-приложение для учёта личных/семейных финансов: баланс, операции,
лимиты бюджета по категориям, AI-инсайты. Работает офлайн (ObjectBox) с
полноценной JWT-авторизацией и синхронизацией с FastAPI-бэкендом.

Ключевые особенности реализации (JWT Auth, Offline First, ObjectBox), архитектура и текущие ограничения подробно описаны в [ARCHITECTURE.md](ARCHITECTURE.md).

## Требования

- [FVM](https://fvm.app/) — используется для фиксации версии Flutter
  (см. `.fvmrc` → Flutter `3.29.3`). Можно и без FVM (см. ниже), но версии
  Flutter/Dart тогда нужно совместить самостоятельно.
- Xcode (для iOS/macOS-сборок, только macOS) с установленными CocoaPods
  (`sudo gem install cocoapods`).
- Android Studio + Android SDK/NDK (для Android-сборок).
- Для запуска на устройствах — авторизованный доступ (Android: USB-debug,
  iOS: доверенный сертификат разработчика/Apple ID в Xcode).

## Установка

```bash
# Один раз: поставить FVM (если ещё не установлен)
brew tap leoafarias/fvm && brew install fvm

# Поставить/активировать версию Flutter, зафиксированную в .fvmrc
fvm install
fvm use

# Подтянуть зависимости
fvm flutter pub get
```

Если не используете FVM — замените `fvm flutter` на `flutter` во всех
командах ниже (нужен Flutter 3.29.3 или совместимый).

## Переменные окружения (`.env`)

Приложение не хранит адреса бэкенда, ключи и прочие настройки окружения в
коде — они читаются из `.env` через `flutter_dotenv`
(см. `lib/config/environment.dart` и `lib/config/api_config.dart`). Файл `.env` **не коммитится**
(в `.gitignore`), в репозитории лежит только шаблон.

```bash
cp .env.example .env
# затем отредактируйте .env под своё окружение
```

Переменные:

| Переменная      | Назначение                              | Пример для Android-эмулятора |
|-----------------|-------------------------------------------|-------------------------------|
| `API_BASE_URL`  | URL окружения `local` (`/api/v1`)         | `http://10.0.2.2:8000/api/v1` |
| `DEV_API_BASE_URL`  | URL окружения `dev`                   | `https://dev.api.example.com/api/v1` |
| `PROD_API_BASE_URL` | URL окружения `prod`                  | `https://api.example.com/api/v1` |

Окружение выбирается в debug/profile-сборках через скрытое Debug-меню
(5 тапов по версии приложения на экране профиля; смена требует перезапуска).
В release-сборке всегда используется `prod`, Debug-меню недоступно.

Если `.env` отсутствует, приложение не падает — используется дефолтный
адрес для Android-эмулятора (см. `ApiConfig`). Для iOS-симулятора и
реальных устройств адрес почти наверняка нужно поменять (см. комментарии
в `.env.example`).

**Никогда не коммитьте реальный `.env`, ключи, токены доступа и т.п.** Если
случайно закоммитили секрет — считайте его скомпрометированным: смените
значение/отзовите токен на стороне сервиса, а не просто удаляйте из
следующего коммита (история git его сохранит).

## Кодогенерация (ObjectBox)

Модели БД (`lib/models/models.dart`) генерируют `lib/objectbox.g.dart` и
обновляют `lib/objectbox-model.json`. Перегенерировать нужно после любого
изменения `@Entity()`-классов:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Оба сгенерированных файла коммитятся в git — `objectbox-model.json` хранит
стабильные ID полей между миграциями схемы базы, его нельзя добавлять в
`.gitignore` и нельзя удалять вручную.

## Иконка и экран запуска (Launcher Icons & Splash Screen)

* **Иконка приложения**:
  * Мастер-ассет: `assets/images/app_icon.png` (1024×1024).
  * Конфигурация в `pubspec.yaml` (`flutter_launcher_icons`).
  * Генерация иконок для iOS и Android:
    ```bash
    fvm flutter pub run flutter_launcher_icons
    ```

* **Экран запуска (Native Splash Screen)**:
  * Ассеты логотипов: `assets/images/splash_logo.png` (светлая тема) и `assets/images/splash_logo_dark.png` (темная тема).
  * Конфигурация в `pubspec.yaml` (`flutter_native_splash`).
  * Генерация нативных сплеш-экранов под iOS и Android (включая Android 12+ Splash API):
    ```bash
    fvm flutter pub run flutter_native_splash:create
    ```

## Запуск в режиме разработки

```bash
fvm flutter devices          # посмотреть доступные устройства/эмуляторы
fvm flutter run              # запуск в debug на выбранном/единственном устройстве
```

## Сборки

### Android

```bash
# Debug APK (для разработки/тестирования)
fvm flutter build apk --debug

# Release APK
fvm flutter build apk --release --dart-define=PROD_API_BASE_URL=https://api.your-domain.com/api/v1

# Release App Bundle (для публикации в Google Play)
fvm flutter build appbundle --release --dart-define=PROD_API_BASE_URL=https://api.your-domain.com/api/v1
```

> Перед публикацией в Google Play замените `applicationId` в
> `android/app/build.gradle.kts` (сейчас `com.example.getbalanceai_mobile` —
> шаблонное значение) и настройте боевой ключ подписи вместо debug-ключа,
> которым сейчас подписывается release-сборка (см. `signingConfig` там же).
> Ключ подписи и его пароли храните вне репозитория — например,
> `android/key.properties` (уже в `.gitignore`) и переменные окружения CI.

### iOS

```bash
# Установить/обновить CocoaPods-зависимости (обычно делает flutter run/build сам)
cd ios && pod install && cd ..

# Debug-сборка для симулятора
fvm flutter build ios --debug --simulator

# Release-сборка (нужен подключённый Apple Developer аккаунт и провижининг в Xcode)
fvm flutter build ios --release --dart-define=PROD_API_BASE_URL=https://api.your-domain.com/api/v1

# IPA для распространения (TestFlight/App Store)
fvm flutter build ipa --release --dart-define=PROD_API_BASE_URL=https://api.your-domain.com/api/v1
```

Подпись/провижининг для iOS настраивается в Xcode
(`ios/Runner.xcworkspace` → Signing & Capabilities), а не в коде.


## Обновление и очистка

```bash
# Обновить зависимости в рамках ограничений pubspec.yaml
fvm flutter pub upgrade

# Проверить, какие зависимости отстают от последних версий
fvm flutter pub outdated

# Полная очистка артефактов сборки и кешей (build/, .dart_tool/)
fvm flutter clean

# После clean зависимости и кодогенерацию нужно подтянуть заново
fvm flutter pub get
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Для полной пересборки iOS/Android с нуля (если проблемы со сборкой не
решаются `flutter clean`):

```bash
# iOS: пересобрать CocoaPods
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Android: сбросить Gradle-кэш проекта
cd android && ./gradlew clean && cd ..
```

## Тесты, статический анализ и форматирование

```bash
fvm dart format .       # автоматическое форматирование кода
fvm flutter analyze     # статический анализ (lints)
fvm flutter test        # unit/widget-тесты
```

Если CI/CD падает из-за ошибок форматирования (или pre-commit hook блокирует коммит), выполните локально:
```bash
fvm dart format .
git add .
git commit --amend --no-edit # добавить форматирование в последний коммит
git push --force origin HEAD # обновить ветку
```

Cubit-классы (`lib/cubits/`) покрываются unit-тестами на `bloc_test` и
`mocktail` (`test/cubits_test.dart`) — зависимости (`ApiService`,
`Connectivity`) подменяются моками через конструктор.

`flutter test` запускает виджет-тесты на хостовой машине (не на
эмуляторе), а ObjectBox использует нативную библиотеку — для macOS/Linux/
Windows её нужно один раз установить отдельно (не через `pub get`):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/objectbox/objectbox-dart/v4.3.1/install.sh)
```

Без этого шага `fvm flutter test` упадёт с ошибкой загрузки
`libobjectbox` — это ожидаемо на чистой машине и не связано с багами в коде.

## Безопасность / работа с репозиторием

- Секреты для локальной разработки хранятся в `.env`, но в релизной сборке этот файл **игнорируется полностью**.
- Секреты для релиза передаются только через аргументы командной строки сборки: `--dart-define=...`.
- Никогда не оставляйте секреты прямо в коде или в коммитах.
- Если нужно поделиться доступом к бэкенду для локальной разработки,
  передавайте `.env` вне git (менеджер паролей, защищённый чат) — не
  добавляйте его в `.gitignore`-исключения и не коммитьте "временно".
- `objectbox-model.json` и `objectbox.g.dart` — коммитить всегда,
  остальные сгенерированные артефакты (`build/`, `.dart_tool/`, Pods,
  Gradle-кэш, `.idea/`) — никогда (см. `.gitignore`).
