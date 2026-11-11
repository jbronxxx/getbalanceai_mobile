import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/config/legal_links.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile.dart';
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
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    EnvironmentConfig.setCurrentForTesting(Environment.local);
  });

  tearDown(() {
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    EnvironmentConfig.setCurrentForTesting(Environment.prod);
  });

  group('ProfileLegalCard', () {
    testWidgets(
        'Показывает три документа со знаком внешней ссылки, без иконок слева',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProfileLegalCard()));
      await tester.pumpAndSettle();

      expect(find.text('Условия использования'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.text('Удаление аккаунта и данных'), findsOneWidget);
      expect(
        find.text('Справка: как удалить аккаунт и какие данные удаляются'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(3));
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.leading, isNull);
      }
    });

    // Строки ищем по порядку, чтобы тест не зависел от языка интерфейса.
    const pages = ['/terms', '/privacy', '/delete-account'];

    for (final language in AppLanguage.values) {
      for (final (index, path) in pages.indexed) {
        testWidgets('Тап открывает $path на языке ${language.code}',
            (tester) async {
          LanguageManager.setLanguage(language, save: false);
          Uri? opened;
          await tester.pumpWidget(_buildTestApp(ProfileLegalCard(
            launcher: (uri) async {
              opened = uri;
              return true;
            },
          )));
          await tester.pumpAndSettle();

          await tester.tap(find.byType(ListTile).at(index));
          await tester.pumpAndSettle();

          expect(opened, isNotNull);
          // В окружении local ссылка ведет на локальный бэкенд, а не на прод
          expect(opened!.host, equals('10.0.2.2'));
          expect(opened!.port, equals(8000));
          expect(opened!.path, equals(path));
          expect(opened!.queryParameters['lang'], equals(language.code));
          expect(find.text('Не удалось открыть ссылку'), findsNothing);
        });
      }
    }

    testWidgets('Если ссылку открыть не удалось, показывает ошибку',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(ProfileLegalCard(
        launcher: (_) async => false,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Не удалось открыть ссылку'), findsOneWidget);
    });

    testWidgets('Исключение при открытии ссылки не падает и показывает ошибку',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(ProfileLegalCard(
        launcher: (_) async => throw Exception('no browser'),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Не удалось открыть ссылку'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LegalLinks', () {
    const prodBase = 'https://api.getbalanceai.app/api/v1';

    test('Строит URL страниц от origin бэкенда без пути /api/v1', () {
      expect(
        LegalLinks.url(LegalPage.terms, 'ru', baseUrl: prodBase).toString(),
        equals('https://api.getbalanceai.app/terms?lang=ru'),
      );
      expect(
        LegalLinks.url(LegalPage.privacy, 'en', baseUrl: prodBase).toString(),
        equals('https://api.getbalanceai.app/privacy?lang=en'),
      );
      expect(
        LegalLinks.url(LegalPage.deleteAccount, 'ru', baseUrl: prodBase)
            .toString(),
        equals('https://api.getbalanceai.app/delete-account?lang=ru'),
      );
    });

    test('Сохраняет схему и порт локального бэкенда', () {
      final uri = LegalLinks.url(
        LegalPage.privacy,
        'en',
        baseUrl: 'http://10.0.2.2:8000/api/v1',
      );
      expect(uri.toString(), equals('http://10.0.2.2:8000/privacy?lang=en'));
    });

    test('По умолчанию использует baseUrl текущего окружения', () {
      EnvironmentConfig.setCurrentForTesting(Environment.local);
      final uri = LegalLinks.url(LegalPage.terms, 'en');
      expect(uri.host, equals('10.0.2.2'));
      expect(uri.path, equals('/terms'));
    });

    for (final language in AppLanguage.values) {
      test('Передает язык ${language.code} в параметр lang', () {
        for (final page in LegalPage.values) {
          final uri = LegalLinks.url(page, language.code, baseUrl: prodBase);
          expect(uri.queryParameters['lang'], equals(language.code));
          expect(uri.path, equals('/${page.slug}'));
        }
      });
    }
  });
}
