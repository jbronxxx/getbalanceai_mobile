import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/services/preferences_service.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile_settings_card.dart';
import 'package:getbalanceai_mobile/widgets/profile/theme_mode_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('PreferencesService ThemeMode Unit Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      PreferencesService.instance.themeModeNotifier.value = ThemeMode.system;
      PreferencesService.instance.darkModeNotifier.value = false;
      LanguageManager.initFallback();
    });

    test('По умолчанию режим темы равен ThemeMode.system', () async {
      final mode = await PreferencesService.instance.getThemeMode();
      expect(mode, ThemeMode.system);
    });

    test('saveThemeMode сохраняет ThemeMode.dark и обновляет нотификаторы',
        () async {
      await PreferencesService.instance.saveThemeMode(ThemeMode.dark);
      expect(await PreferencesService.instance.getThemeMode(), ThemeMode.dark);
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.dark);
      expect(PreferencesService.instance.darkModeNotifier.value, isTrue);
      expect(await PreferencesService.instance.getDarkMode(), isTrue);
    });

    test('saveThemeMode сохраняет ThemeMode.light и обновляет нотификаторы',
        () async {
      await PreferencesService.instance.saveThemeMode(ThemeMode.light);
      expect(await PreferencesService.instance.getThemeMode(), ThemeMode.light);
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.light);
      expect(PreferencesService.instance.darkModeNotifier.value, isFalse);
      expect(await PreferencesService.instance.getDarkMode(), isFalse);
    });

    test('saveThemeMode сохраняет ThemeMode.system и обновляет нотификаторы',
        () async {
      await PreferencesService.instance.saveThemeMode(ThemeMode.dark);
      await PreferencesService.instance.saveThemeMode(ThemeMode.system);
      expect(
          await PreferencesService.instance.getThemeMode(), ThemeMode.system);
      expect(PreferencesService.instance.themeModeNotifier.value,
          ThemeMode.system);
      expect(PreferencesService.instance.darkModeNotifier.value, isFalse);
    });

    test('Корректная миграция с legacy флага settings_dark_mode = true',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'settings_dark_mode': 'true',
      });

      final mode = await PreferencesService.instance.getThemeMode();
      expect(mode, ThemeMode.dark);

      await PreferencesService.instance.loadSavedThemeMode();
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.dark);
      expect(PreferencesService.instance.darkModeNotifier.value, isTrue);
    });

    test('Корректная миграция с legacy флага settings_dark_mode = false',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'settings_dark_mode': 'false',
      });

      final mode = await PreferencesService.instance.getThemeMode();
      expect(mode, ThemeMode.light);

      await PreferencesService.instance.loadSavedThemeMode();
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.light);
      expect(PreferencesService.instance.darkModeNotifier.value, isFalse);
    });

    test('Обратная совместимость: saveDarkMode и loadSavedDarkMode', () async {
      await PreferencesService.instance.saveDarkMode(true);
      expect(await PreferencesService.instance.getThemeMode(), ThemeMode.dark);
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.dark);

      await PreferencesService.instance.saveDarkMode(false);
      expect(await PreferencesService.instance.getThemeMode(), ThemeMode.light);
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.light);
    });
  });

  group('ThemeModePickerSheet Widget Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      PreferencesService.instance.themeModeNotifier.value = ThemeMode.system;
      LanguageManager.initFallback();
    });

    testWidgets('Отображает заголовок «Тема оформления» и 3 пункта без иконок',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ThemeModePickerSheet(),
        ),
      );
      await tester.pump();

      expect(find.text('Тема оформления'), findsOneWidget);
      expect(find.text('Системная'), findsOneWidget);
      expect(find.text('Светлая'), findsOneWidget);
      expect(find.text('Темная'), findsOneWidget);

      // Проверяем наличие галочки только у выбранного пункта «Системная»
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Выбор пункта «Темная» сохраняет режим и вызывает колбэк',
        (tester) async {
      var callbackCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          ThemeModePickerSheet(
            onThemeChanged: () => callbackCalled = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Темная'));
      await tester.pumpAndSettle();

      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.dark);
      expect(callbackCalled, isTrue);
    });

    testWidgets('Статические методы getThemeTitle и getThemeModeLabel',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              expect(ThemeModePickerSheet.getThemeTitle(context),
                  'Тема оформления');
              expect(
                  ThemeModePickerSheet.getThemeModeLabel(
                      context, ThemeMode.system),
                  'Системная');
              expect(
                  ThemeModePickerSheet.getThemeModeLabel(
                      context, ThemeMode.light),
                  'Светлая');
              expect(
                  ThemeModePickerSheet.getThemeModeLabel(
                      context, ThemeMode.dark),
                  'Темная');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
    });
  });

  group('ProfileSettingsCard Theme Integration Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      PreferencesService.instance.themeModeNotifier.value = ThemeMode.system;
      PreferencesService.instance.darkModeNotifier.value = false;
      LanguageManager.initFallback();
    });

    testWidgets(
        'Отображает строку меню «Тема оформления» без иконки и текущее значение',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ProfileSettingsCard(
            onLanguageChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тема оформления'), findsOneWidget);
      expect(find.text('Системная'), findsOneWidget);
      // Пункт меню без leading-иконок
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets(
        'Тап по строке темы открывает дропдаун и выбор темы обновляет значение',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ProfileSettingsCard(
            onLanguageChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Нажимаем на пункт меню «Тема оформления»
      await tester.tap(find.text('Тема оформления'));
      await tester.pumpAndSettle();

      // Открылся ThemeModePickerSheet с вариантами выбора
      expect(find.byType(ThemeModePickerSheet), findsOneWidget);
      expect(find.text('Темная'), findsOneWidget);

      // Выбираем «Темная»
      await tester.tap(find.text('Темная'));
      await tester.pumpAndSettle();

      // Шит закрылся, а в строке настроек отображается «Темная»
      expect(find.byType(ThemeModePickerSheet), findsNothing);
      expect(
          PreferencesService.instance.themeModeNotifier.value, ThemeMode.dark);
      expect(await PreferencesService.instance.getThemeMode(), ThemeMode.dark);
      expect(find.text('Темная'), findsOneWidget);
    });
  });
}
