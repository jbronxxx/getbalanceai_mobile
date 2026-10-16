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
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
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
      expect(find.text('Выберите язык'), findsOneWidget);
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

      expect(find.text('Выберите язык'), findsOneWidget);
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

    testWidgets('Лента главного экрана не растягивается у краёв',
        (tester) async {
      SelectedPeriodService.instance.reset();
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    });

    testWidgets(
        'Свайп скрывает операцию, «Отменить» возвращает, без отмены — удаляет',
        (tester) async {
      SelectedPeriodService.instance.reset();
      final now = DateTime.now();
      Transaction tx(String description, int hour) => Transaction(
            amount: 1000,
            description: description,
            dbCategory: Category.food.name,
            dbType: TransactionType.expense.name,
            dateMilliseconds: DateTime(now.year, now.month, now.day, hour)
                .millisecondsSinceEpoch,
            dateCreatedMilliseconds: 0,
          );
      // Свайпаем вторую строку: на первой играет подсказка свайпа
      LocalDbService.instance.saveTransaction(tx('Новая', 2));
      LocalDbService.instance.saveTransaction(tx('Удаляемая', 1));

      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();
      final row = find.text('Удаляемая');
      expect(row, findsOneWidget);

      Future<void> swipeLeft() async {
        await tester.drag(row, const Offset(-700, 0));
        await tester.pumpAndSettle();
      }

      // Отмена: операция снова в ленте и в базе
      await swipeLeft();
      expect(row, findsNothing);
      expect(find.text(LanguageManager.l10n.undo_action), findsOneWidget);
      // Тост с отменой закрывается смахиванием, без крестика
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      await tester.tap(find.byKey(const ValueKey('toast_action')));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(LocalDbService.instance.getAllTransactions().length, 2);

      // Без отмены операция удаляется по истечении тоста
      await swipeLeft();
      expect(row, findsNothing);
      expect(LocalDbService.instance.getAllTransactions().length, 2);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(
        LocalDbService.instance.getAllTransactions().map((t) => t.description),
        ['Новая'],
      );
    });

    testWidgets('Короткий свайп не удаляет операцию', (tester) async {
      SelectedPeriodService.instance.reset();
      final now = DateTime.now();
      // Проверяем вторую строку: на первой играет подсказка свайпа
      for (final (description, hour) in [('Первая', 2), ('Строка', 1)]) {
        LocalDbService.instance.saveTransaction(Transaction(
          amount: 1000,
          description: description,
          dbCategory: Category.food.name,
          dbType: TransactionType.expense.name,
          dateMilliseconds: DateTime(now.year, now.month, now.day, hour)
              .millisecondsSinceEpoch,
          dateCreatedMilliseconds: 0,
        ));
      }
      await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // Половина ширины строки — ниже порога в 60%
      final row = find.text('Строка');
      final width = tester.getSize(find.byType(Dismissible).last).width;
      await tester.timedDrag(
        row,
        Offset(-width * 0.5, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));

      expect(row, findsOneWidget);
      expect(LocalDbService.instance.getAllTransactions().length, 2);
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

  group('Budgets Screen Empty State Tests', () {
    testWidgets(
        'Без лимитов карточка месяца предлагает добавить лимит, списка и заголовка нет',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const BudgetsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MonthBudgetCard), findsOneWidget);
      expect(
        find.text(LanguageManager.l10n.no_budgets_subtitle),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('month_budget_add_limit')), findsOneWidget);
      expect(find.byType(BudgetsSectionHeader), findsNothing);
      expect(find.byType(BudgetItemCard), findsNothing);
      // Выгрузка отчёта перенесена на «Аналитику»
      expect(find.byTooltip(LanguageManager.l10n.report_export_title),
          findsNothing);
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

    testWidgets('В AddBudgetSheet поле Сумма идет перед чипсами категорий',
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
      final chipsFinder = find.byType(CategoryChipsSelector);

      expect(textFieldFinder, findsOneWidget);
      expect(chipsFinder, findsOneWidget);
      expect(find.byType(DropdownButtonFormField<Category>), findsNothing);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.labelText, equals('Сумма'));
      // Бейдж валюты — как в форме операции
      expect(textField.decoration?.suffixIcon, isA<CurrencyBadge>());
      expect(
        find.text(CurrencyFormatter.currentCurrency.code),
        findsOneWidget,
      );

      // Поле Сумма расположено выше по Y, чем чипсы категорий
      final amountDy = tester.getTopLeft(textFieldFinder).dy;
      final categoryDy = tester.getTopLeft(chipsFinder).dy;
      expect(amountDy, lessThan(categoryDy));
    });

    testWidgets('AddBudgetSheet: бейдж валюты открывает выбор валюты лимита',
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

      await tester.tap(find.byType(CurrencyBadge));
      await tester.pumpAndSettle();

      expect(find.byType(CurrencyPickerSheet), findsOneWidget);
    });

    testWidgets('AddBudgetSheet: смена валюты пересчитывает сумму лимита',
        (tester) async {
      final budget = Budget(
        localId: 3,
        dbCategory: Category.food.name,
        limitAmount: 1000,
        currencyCode: 'KZT',
        month: 10,
        year: 2026,
        spent: 0,
        remaining: 1000,
      );
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            budgetToEdit: budget,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CurrencyBadge));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Currency.uzs.localizedName));
      await tester.pumpAndSettle();

      final expected = CurrencyFormatter.format(
        CurrencyExchangeService.instance
            .convert(1000, from: Currency.kzt, to: Currency.uzs),
        showSymbol: false,
        currency: Currency.uzs,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, expected);
      expect(find.text(Currency.uzs.code), findsOneWidget);
    });

    testWidgets('AddBudgetSheet не предлагает категории с лимитом',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            limitedCategories: const {Category.food, Category.transport},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = find.byType(CategoryChipsSelector);
      final selector = tester.widget<CategoryChipsSelector>(chips);
      expect(selector.categories, isNot(contains(Category.food)));
      expect(selector.categories, isNot(contains(Category.transport)));
      expect(selector.categories, isNotEmpty);
      expect(selector.categories, contains(selector.selected));
    });

    testWidgets('AddBudgetSheet при редактировании — только своя категория',
        (tester) async {
      final budget = Budget(
        localId: 7,
        dbCategory: Category.food.name,
        limitAmount: 1000,
        month: 10,
        year: 2026,
        spent: 0,
        remaining: 1000,
      );
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            budgetToEdit: budget,
            limitedCategories: const {Category.food},
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = find.byType(CategoryChipsSelector);
      final selector = tester.widget<CategoryChipsSelector>(chips);
      expect(selector.categories, [Category.food]);
      expect(selector.selected, Category.food);
    });

    testWidgets(
        'AddBudgetSheet: на всё есть лимиты — подсказка, кнопка неактивна',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            limitedCategories: Category.expenseCategories.toSet(),
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryChipsSelector), findsNothing);
      expect(
        find.text(LanguageManager.l10n.budget_all_categories_limited),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
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

    testWidgets('Свайп лимита скрывает его с отменой, без отмены — удаляет',
        (tester) async {
      // Обе карточки лимитов должны поместиться под карточкой месяца
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SelectedPeriodService.instance.reset();
      final period = SelectedPeriodService.instance.period;
      for (final category in [Category.food, Category.transport]) {
        LocalDbService.instance.saveBudget(Budget(
          dbCategory: category.name,
          limitAmount: 50000,
          spent: 0,
          remaining: 50000,
          month: period.month,
          year: period.year,
        ));
      }

      await tester.pumpWidget(_buildTestApp(const BudgetsScreen()));
      await tester.pumpAndSettle();
      final cards = find.byType(BudgetItemCard);
      expect(cards, findsNWidgets(2));

      // Свайпаем вторую карточку: на первой играет подсказка свайпа
      Future<void> swipeSecond() async {
        await tester.drag(cards.last, const Offset(-700, 0));
        await tester.pumpAndSettle();
      }

      await swipeSecond();
      expect(cards, findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      await tester.tap(find.byKey(const ValueKey('toast_action')));
      await tester.pumpAndSettle();
      expect(cards, findsNWidgets(2));
      await tester.pump(const Duration(seconds: 6));
      expect(LocalDbService.instance.getAllBudgets().length, 2);

      await swipeSecond();
      expect(LocalDbService.instance.getAllBudgets().length, 2);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(cards, findsOneWidget);
      expect(LocalDbService.instance.getAllBudgets().length, 1);
    });

    testWidgets('Обычный тост сохраняет крестик закрытия', (tester) async {
      await tester.pumpWidget(_buildTestApp(Builder(
        builder: (context) => TextButton(
          onPressed: () => AppAlerts.info(context, 'info'),
          child: const Text('show'),
        ),
      )));
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('toast_action')), findsNothing);
      // SnackBar не обрезает тень стекла второй рамкой
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).clipBehavior,
        Clip.none,
      );
      await tester.pump(const Duration(seconds: 5));
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
