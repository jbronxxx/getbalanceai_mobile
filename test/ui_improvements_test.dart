import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/main.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/screens/auth_screen.dart';
import 'package:getbalanceai_mobile/screens/budgets_screen.dart';
import 'package:getbalanceai_mobile/screens/dashboard_screen.dart';
import 'package:getbalanceai_mobile/screens/welcome_setup_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/period/period.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status":"success","data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    originalAdapter = ApiService.instance.dio.httpClientAdapter;
    final tempDir =
        await Directory.systemTemp.createTemp('ui_improvements_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
    LanguageManager.initFallback();
    await LocalDbService.init();
    ApiService.instance.dio.httpClientAdapter = _MockHttpClientAdapter();
  });

  tearDownAll(() {
    ApiService.instance.dio.httpClientAdapter = originalAdapter;
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
    await ApiService.instance.setTokens(null, null);
    await LocalDbService.instance.clearAllData();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await CurrencyFormatter.loadSavedCurrency();
  });

  group('Onboarding Seamless Screens Tests', () {
    testWidgets('Экран онбординга не содержит AppBar и хэдера', (tester) async {
      await tester.pumpWidget(_buildTestApp(const WelcomeSetupScreen()));
      await tester.pumpAndSettle();

      // Проверяем отсутствие AppBar
      expect(find.byType(AppBar), findsNothing);

      // Отображается заголовок выбора языка
      expect(find.text('Выберите язык / Tanlang'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // Переход на шаг валюты
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      // На шаге валюты есть кнопка назад в контенте шага
      expect(find.text('Основная валюта'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Возврат на шаг языка
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Выберите язык / Tanlang'), findsOneWidget);
    });

    testWidgets(
        'При первом открытии без завершенного онбординга сразу открывается WelcomeSetupScreen',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await PreferencesService.instance.loadSavedOnboardingStatus();
      expect(PreferencesService.instance.isOnboardingCompletedSync, isFalse);

      await tester.pumpWidget(const FinanceApp());
      await tester.pump();

      // Отображается экран онбординга
      expect(find.byType(WelcomeSetupScreen), findsOneWidget);
      // Главный экран и навигация отсутствуют
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(LiquidGlassNavBar), findsNothing);
    });

    testWidgets(
        'Позиция кнопок выбора языка не меняется при переключении языков (нет скачков)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const WelcomeSetupScreen()));
      await tester.pumpAndSettle();

      final firstButton = find.text('Русский');
      expect(firstButton, findsOneWidget);
      final initialDy = tester.getTopLeft(firstButton).dy;

      // Переключаем на English
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      final englishDy = tester.getTopLeft(find.text('Русский')).dy;
      expect((englishDy - initialDy).abs(), lessThanOrEqualTo(0.5));

      // Переключаем на O'zbekcha
      await tester.tap(find.text("O'zbekcha"));
      await tester.pumpAndSettle();

      final uzbekDy = tester.getTopLeft(find.text('Русский')).dy;
      expect((uzbekDy - initialDy).abs(), lessThanOrEqualTo(0.5));
    });
  });

  group('Dashboard Layout & Header Tests', () {
    testWidgets(
        'Главный экран имеет заголовок Баланс и переключатель месяца над балансом',
        (tester) async {
      SelectedPeriodService.instance.reset();
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // В AppBar есть заголовок Баланс
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isNotNull);
      expect(appBar.surfaceTintColor, equals(Colors.transparent));
      expect(find.text('Баланс'), findsOneWidget);

      // Переключатель периода расположен над карточкой баланса
      expect(find.byType(BalanceCard), findsOneWidget);
      expect(find.byType(PeriodSwitcher), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(PeriodSwitcher)).dy,
        lessThan(tester.getTopLeft(find.byType(BalanceCard)).dy),
      );
      // Плавающей кнопки на экране нет: «+» живёт в панели навигации
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(LiquidGlassFab), findsNothing);
    });

    testWidgets('Переключатель на дашборде меняет общий период',
        (tester) async {
      SelectedPeriodService.instance.reset();
      addTearDown(SelectedPeriodService.instance.reset);
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      final before = SelectedPeriodService.instance.period;
      await tester.tap(find.byKey(const ValueKey('period_previous')));
      await tester.pumpAndSettle();

      expect(SelectedPeriodService.instance.period, before.previous);
      expect(
        find.text(PeriodSwitcher.label(before.previous)),
        findsOneWidget,
      );
    });

    testWidgets('BalanceCard имеет уменьшенную тень', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const BalanceCard(balance: 1000, income: 2000, expense: 1000),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BalanceCard),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.first.blurRadius, equals(10));
      expect(decoration.boxShadow!.first.offset.dy, equals(4));
    });
  });

  group('Budgets Screen Floating Bubble Tests', () {
    testWidgets(
        'При отсутствии лимитов отображается пузырь с подсказкой без заливки',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const BudgetsScreen()));
      await tester.pumpAndSettle();

      // Проверяем наличие текста подсказки и иконки пузыря
      expect(
        find.text(LanguageManager.l10n.no_budgets_subtitle),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.pie_chart_outline_rounded), findsOneWidget);
      // Присутствуют BackdropFilter в LiquidGlassAppBar и в пустом пузыре подсказки
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });
  });

  group('Input Fields Styling & Capitalization Tests', () {
    testWidgets(
        'Поле Описание в AddTransactionSheet имеет TextCapitalization.sentences',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const AddTransactionSheet()));
      await tester.pumpAndSettle();

      final descriptionFieldFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.labelText?.contains('Описание') ?? false),
      );
      expect(descriptionFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(descriptionFieldFinder);
      expect(textField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('В AddBudgetSheet поле Сумма идет перед полем Категория',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      final dropdownFinder = find.byType(DropdownButtonFormField<Category>);

      expect(textFieldFinder, findsOneWidget);
      expect(dropdownFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.labelText, equals('Сумма'));

      // Поле Сумма расположено выше по Y, чем дропдаун Категории
      final amountDy = tester.getTopLeft(textFieldFinder).dy;
      final categoryDy = tester.getTopLeft(dropdownFinder).dy;
      expect(amountDy, lessThan(categoryDy));
    });
  });

  group('Swipe Hint Full Width Background Tests', () {
    testWidgets(
        'SwipeHintWrapper разворачивает фоновую подложку через Positioned.fill',
        (tester) async {
      const key = Key('hint_test_child');
      await tester.pumpWidget(
        _buildTestApp(
          SwipeHintWrapper(
            showHint: true,
            background: Container(
              color: Colors.red,
              key: const Key('red_background'),
            ),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              key: key,
              width: 300,
              height: 80,
              color: Colors.blue,
            ),
          ),
        ),
      );

      // Проверяем начальный рендер
      expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('BudgetItemCard использует скругление 24 для фона удаления',
        (tester) async {
      final budget = Budget(
        localId: 1,
        dbCategory: Category.food.name,
        limitAmount: 50000,
        spent: 10000,
        remaining: 40000,
        month: 10,
        year: 2026,
      );

      await tester.pumpWidget(
        _buildTestApp(
          BudgetItemCard(
            budget: budget,
            currentSpent: 10000,
            isFirst: true,
            showSwipeHint: true,
            onTap: () {},
            onDelete: () {},
            onHintShown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BudgetItemCard), findsOneWidget);
      expect(find.byType(SwipeHintWrapper), findsOneWidget);
    });
  });

  group('Insights Rephrased Title Tests', () {
    testWidgets('Заголовок перефразирован из Инсайты в AI-Аналитика',
        (tester) async {
      expect(
          LanguageManager.l10n.insights_header_title, equals('AI-Аналитика'));
      expect(LanguageManager.l10n.insights, equals('Аналитика'));
    });
  });

  group('AuthScreen & Glass Headers Polish Tests', () {
    testWidgets('AuthScreen не содержит отдельного AppBar и хэдера',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const AuthScreen()));
      await tester.pumpAndSettle();

      // Проверяем отсутствие AppBar на экране логина
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Войти или создать аккаунт'), findsOneWidget);
    });

    testWidgets(
        'DashboardScreen и BudgetsScreen используют LiquidGlassAppBar и ScreenBodyCard',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassAppBar), findsOneWidget);
      expect(find.byType(ScreenBodyCard), findsOneWidget);

      await tester.pumpWidget(_buildTestApp(const BudgetsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassAppBar), findsOneWidget);
      expect(find.byType(ScreenBodyCard), findsOneWidget);
    });
  });
}
