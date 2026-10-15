import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/screens/welcome_setup_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp(Widget child) {
  return ValueListenableBuilder<AppLanguage>(
    valueListenable: LanguageManager.languageNotifier,
    builder: (context, lang, _) {
      return MaterialApp(
        locale: Locale(lang.code),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'FinanceApp',
      packageName: 'com.finance.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.usd);
  });

  tearDown(() {
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.usd);
  });

  group('AppLanguage.kk & LanguageManager Unit Tests', () {
    test('Свойства элемента перечисления AppLanguage.kk', () {
      expect(AppLanguage.kk.code, equals('kk'));
      expect(AppLanguage.kk.displayName, equals('Қазақша'));
      expect(AppLanguage.kk.flag, equals('🇰🇿'));
    });

    test('Переключение языка на казахский и доступ к строкам локализации', () {
      LanguageManager.setLanguage(AppLanguage.kk, save: false);

      expect(LanguageManager.currentLanguage, equals(AppLanguage.kk));
      expect(LanguageManager.code, equals('kk'));
      expect(LanguageManager.languageNotifier.value, equals(AppLanguage.kk));

      final l10n = LanguageManager.l10n;
      expect(l10n.balance, equals('Баланс'));
      expect(l10n.finances, equals('Бюджет'));
      expect(l10n.insights, equals('Талдау'));
      expect(l10n.kzt_name, equals('Қазақстан теңгесі'));
      expect(l10n.usd_name, equals('АҚШ доллары'));
      expect(l10n.eur_name, equals('Еуро'));
      expect(l10n.uzs_name, equals('Өзбек сомы'));
      expect(l10n.continue_btn, equals('Жалғастыру'));
      expect(l10n.amount_label, equals('Сомасы'));
      expect(l10n.category_food, equals('Тамақтану'));
      expect(l10n.category_transport, equals('Көлік'));
    });

    test('Форматирование дня и месяца (formatDayMonth) для казахского языка',
        () {
      LanguageManager.setLanguage(AppLanguage.kk, save: false);

      final dateOct14 = DateTime(2026, 10, 14);
      expect(LanguageManager.formatDayMonth(dateOct14), equals('14 қазан'));

      final dateJan1 = DateTime(2026, 1, 1);
      expect(LanguageManager.formatDayMonth(dateJan1), equals('1 қаңтар'));

      final dateMay25 = DateTime(2026, 5, 25);
      expect(LanguageManager.formatDayMonth(dateMay25), equals('25 мамыр'));
    });

    test(
        'Форматирование даты и времени (formatDateTime) для текущего и другого года',
        () {
      LanguageManager.setLanguage(AppLanguage.kk, save: false);

      final now = DateTime.now();
      final dateSameYear = DateTime(now.year, 10, 14, 15, 30);
      expect(
        LanguageManager.formatDateTime(dateSameYear),
        equals('14 қазан, 15:30'),
      );

      final dateOtherYear = DateTime(2023, 3, 22, 9, 5);
      expect(
        LanguageManager.formatDateTime(dateOtherYear),
        equals('2023 ж. 22 наурыз, 09:05'),
      );

      expect(
        LanguageManager.formatDate(dateOtherYear, includeTime: false),
        equals('22 наурыз'),
      );
    });

    test(
        'Форматирование счетчика операций (formatOperationsCount) на казахском языке',
        () {
      LanguageManager.setLanguage(AppLanguage.kk, save: false);

      expect(LanguageManager.formatOperationsCount(0), equals('0 операция'));
      expect(LanguageManager.formatOperationsCount(1), equals('1 операция'));
      expect(LanguageManager.formatOperationsCount(2), equals('2 операция'));
      expect(LanguageManager.formatOperationsCount(5), equals('5 операция'));
      expect(LanguageManager.formatOperationsCount(11), equals('11 операция'));
      expect(LanguageManager.formatOperationsCount(21), equals('21 операция'));
      expect(
          LanguageManager.formatOperationsCount(100), equals('100 операция'));
    });

    test('Сохранение и загрузка казахского языка через PreferencesService',
        () async {
      await PreferencesService.instance.saveLanguage('kk');
      final savedCode = await PreferencesService.instance.getLanguage();
      expect(savedCode, equals('kk'));

      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      expect(LanguageManager.currentLanguage, equals(AppLanguage.ru));

      await LanguageManager.loadSavedLanguage();
      expect(LanguageManager.currentLanguage, equals(AppLanguage.kk));
    });
  });

  group('WelcomeSetupScreen Kazakh & Auto KZT Tests', () {
    testWidgets(
        'Выбор Қазақша на шаге 1 автоматически переключает валюту на KZT',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const WelcomeSetupScreen()));
      await tester.pumpAndSettle();

      // Проверяем отображение казахского языка в списке
      expect(find.text('Қазақша'), findsOneWidget);

      // Тапаем на Қазақша
      await tester.tap(find.text('Қазақша'));
      await tester.pumpAndSettle();

      // Язык переключился, кнопка продолжения локализована на казахский
      expect(find.text('Жалғастыру'), findsOneWidget);

      // Переходим на шаг 2 (выбор валюты)
      await tester.tap(find.text('Жалғастыру'));
      await tester.pumpAndSettle();

      // На шаге валюты Қазақстан теңгесі выбран по умолчанию
      final kztTile = find.ancestor(
        of: find.text('Қазақстан теңгесі'),
        matching: find.byType(ListTile),
      );
      expect(kztTile, findsOneWidget);
      expect(
        find.descendant(
          of: kztTile,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'Ручной выбор валюты не перезаписывается при возврате и смене языка на Қазақша',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const WelcomeSetupScreen()));
      await tester.pumpAndSettle();

      // Переходим сразу на шаг 2
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      // Вручную выбираем EUR (на русском это "Евро")
      await tester.tap(find.text('Евро'));
      await tester.pumpAndSettle();

      // Возвращаемся назад на шаг 1
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Переключаем язык на Қазақша
      await tester.tap(find.text('Қазақша'));
      await tester.pumpAndSettle();

      // Снова переходим на шаг 2
      await tester.tap(find.text('Жалғастыру'));
      await tester.pumpAndSettle();

      // Ручной выбор EUR сохранен (на казахском это "Еуро"), а не перезаписан на KZT
      final eurTile = find.ancestor(
        of: find.text('Еуро'),
        matching: find.byType(ListTile),
      );
      expect(eurTile, findsOneWidget);
      expect(
        find.descendant(
          of: eurTile,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('WelcomeLanguageSheet Kazakh & Auto KZT Tests', () {
    testWidgets('В модальной шторке выбор Қазақша автоматически выставляет KZT',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => WelcomeLanguageSheet.show(context),
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // В шторке присутствует пункт Қазақша
      expect(find.text('Қазақша'), findsOneWidget);

      // Тапаем на Қазақша
      await tester.tap(find.text('Қазақша'));
      await tester.pumpAndSettle();

      // KZT выбран
      expect(LanguageManager.currentLanguage, equals(AppLanguage.kk));
      expect(find.text('KZT'), findsOneWidget);
    });
  });

  group('LanguagePickerSheet Kazakh Selection Tests', () {
    testWidgets(
        'В шторке выбора языка профиля отображается Қазақша и переключает язык',
        (tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LanguagePickerSheet.show(
                    context,
                    onLanguageChanged: () => callbackCalled = true,
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Қазақша'), findsOneWidget);

      await tester.tap(find.text('Қазақша'));
      await tester.pumpAndSettle();

      expect(LanguageManager.currentLanguage, equals(AppLanguage.kk));
      expect(callbackCalled, isTrue);
    });
  });
}
