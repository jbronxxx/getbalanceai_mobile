import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'support/app_fonts.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.usd);
  });

  Widget buildTestWidget({
    required double totalIncome,
    required double totalExpense,
    required Map<Category, double> categoryExpenses,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BudgetExpenseRatioCard(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            categoryExpenses: categoryExpenses,
          ),
        ),
      ),
    );
  }

  testWidgets('Happy Path: нормальное соотношение расхода к доходу (50%)',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 100000,
      totalExpense: 50000,
      categoryExpenses: {
        Category.food: 30000,
        Category.transport: 20000,
      },
    ));
    await tester.pumpAndSettle();

    // Проверяем наличие заголовка
    expect(find.text('Структура расходов'), findsOneWidget);
    // Проверяем бейдж и кольцо 50%
    expect(find.textContaining('50%'), findsWidgets);
    expect(find.text('от дохода'), findsWidgets);
    // Процент не дублируется бейджем: он есть только при перерасходе
    expect(find.textContaining('!'), findsNothing);
    // Проверяем категории в легенде
    expect(find.text(Category.food.getLocalizedName()), findsOneWidget);
    expect(find.text(Category.transport.getLocalizedName()), findsOneWidget);
    // Проверяем итоговые суммы в чипах: Доход слева, Расход справа (по аналогии с BalanceCard)
    expect(find.text(LanguageManager.l10n.income_title), findsOneWidget);
    expect(find.text(LanguageManager.l10n.expense_title), findsOneWidget);
    final incomeOffset =
        tester.getTopLeft(find.text(LanguageManager.l10n.income_title));
    final expenseOffset =
        tester.getTopLeft(find.text(LanguageManager.l10n.expense_title));
    expect(incomeOffset.dx, lessThan(expenseOffset.dx));
  });

  testWidgets('Кейс: отсутствие прихода (доход = 0, только расходы)',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 0,
      totalExpense: 35000,
      categoryExpenses: {
        Category.food: 20000,
        Category.shopping: 15000,
      },
    ));
    await tester.pumpAndSettle();

    // Без дохода бейджа нет: «всего трат» в центре кольца
    expect(find.textContaining('!'), findsNothing);
    // Проверяем центр кольца (100% расходов распределено)
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('всего трат'), findsOneWidget);
    // Проверяем отображение категорий
    expect(find.text(Category.food.getLocalizedName()), findsOneWidget);
    expect(find.text(Category.shopping.getLocalizedName()), findsOneWidget);
  });

  testWidgets('Кейс: перерасход (расход > дохода, более 100%)', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 50000,
      totalExpense: 75000,
      categoryExpenses: {
        Category.food: 75000,
      },
    ));
    await tester.pumpAndSettle();

    // Процент — только в центре кольца, без бейджа перерасхода в шапке
    expect(find.text('150%'), findsOneWidget);
    expect(find.textContaining('!'), findsNothing);
  });

  testWidgets('Кейс: пустой месяц без операций (доход = 0, расход = 0)',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 0,
      totalExpense: 0,
      categoryExpenses: {},
    ));
    await tester.pumpAndSettle();

    // Статус 0%
    expect(find.text('0%'), findsWidgets);
    // Плейсхолдер — про расходы, а не «нет записей» (UX-06): на экране
    // карточка видна только при доходах или расходах
    expect(find.text(LanguageManager.l10n.structure_no_expenses_month),
        findsOneWidget);
    expect(find.text(LanguageManager.l10n.no_transactions), findsNothing);
  });

  testWidgets(
      'стрелки дохода и расхода — диагональные и цветные, как на «Балансе»',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 1000,
      totalExpense: 400,
      categoryExpenses: {Category.food: 400},
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.south_west_rounded), findsOneWidget);
    expect(find.byIcon(Icons.north_east_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    // UX-13: цвета стрелок — те же, что на карточке «Баланса»
    Color? iconColor(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color;
    expect(iconColor(Icons.south_west_rounded), AppColors.incomeOnBrand);
    expect(iconColor(Icons.north_east_rounded), AppColors.expenseOnBrand);
  });

  testWidgets('Кейс: группировка при более чем 4 категориях (+N ещё)',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 100000,
      totalExpense: 60000,
      categoryExpenses: {
        Category.food: 25000,
        Category.transport: 15000,
        Category.entertainment: 10000,
        Category.health: 6000,
        Category.shopping: 4000,
      },
    ));
    await tester.pumpAndSettle();

    // Топ-3 видны по отдельности
    expect(find.text(Category.food.getLocalizedName()), findsOneWidget);
    expect(find.text(Category.transport.getLocalizedName()), findsOneWidget);
    expect(
        find.text(Category.entertainment.getLocalizedName()), findsOneWidget);
    // Оставшиеся 2 сворачиваются в строку «ещё 2 категории»
    expect(find.text(Category.health.getLocalizedName()), findsNothing);
    expect(find.text('ещё 2 категории'), findsOneWidget);
  });

  testWidgets('Кейс: ровно 4 категории — все видны, без «ещё 1»',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 100000,
      totalExpense: 56000,
      categoryExpenses: {
        Category.food: 25000,
        Category.transport: 15000,
        Category.entertainment: 10000,
        Category.health: 6000,
      },
    ));
    await tester.pumpAndSettle();

    for (final c in [
      Category.food,
      Category.transport,
      Category.entertainment,
      Category.health,
    ]) {
      expect(find.text(c.getLocalizedName()), findsOneWidget);
    }
    expect(find.textContaining('ещё'), findsNothing);
  });

  testWidgets('Реактивность: карточка обновляет анимацию при изменении пропсов',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 100000,
      totalExpense: 40000,
      categoryExpenses: {Category.food: 40000},
    ));
    await tester.pumpAndSettle();

    expect(find.text('40%'), findsWidgets);

    // Обновляем виджет с новыми суммами
    await tester.pumpWidget(buildTestWidget(
      totalIncome: 100000,
      totalExpense: 80000,
      categoryExpenses: {Category.food: 80000},
    ));
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsWidgets);
  });

  group('UX-16: подпись в центре кольца', () {
    setUpAll(loadAppFonts);

    /// Карточка на телефоне 360 dp с масштабом шрифта [scale].
    Future<void> pumpCard(
        WidgetTester tester, AppLanguage language, double scale, double income,
        {double expense = 35000, double width = 360}) async {
      LanguageManager.setLanguage(language, save: false);
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(language.name),
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BudgetExpenseRatioCard(
              totalIncome: income,
              totalExpense: expense,
              categoryExpenses: {Category.food: expense},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final scale in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      testWidgets('блок вписан в отверстие кольца, шрифт ×$scale',
          (tester) async {
        final outside = <String>[];
        for (final language in AppLanguage.values) {
          // Без дохода — «всего трат», с доходом — «от дохода»
          for (final income in [0.0, 100000.0]) {
            await pumpCard(tester, language, scale, income);
            final donut = tester.getCenter(find.byType(CustomPaint).last);
            final box =
                tester.getRect(find.byKey(const ValueKey('donut_center')));
            // Отверстие — круг радиусом 40 (кольцо 100, толщина 10)
            final farthest = [
              box.topLeft,
              box.topRight,
              box.bottomLeft,
              box.bottomRight
            ].map((p) => (p - donut).distance).reduce(math.max);
            if (farthest > 40) {
              outside.add('${language.name}, доход $income: '
                  '${farthest.toStringAsFixed(1)}');
            }
          }
        }
        expect(outside, isEmpty);
      });
    }

    testWidgets(
        '×2, узкий экран, десятки миллионов: ни один текст не обрезан «…»',
        (tester) async {
      await CurrencyFormatter.setCurrency(Currency.eur);
      addTearDown(() => CurrencyFormatter.setCurrency(Currency.usd));
      final cut = <String>[];
      for (final language in AppLanguage.values) {
        await pumpCard(tester, language, 2.0, 0, expense: 35983616, width: 320);
        for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
          if (p.didExceedMaxLines) {
            cut.add('${language.name}: «${p.text.toPlainText()}»');
          }
        }
      }
      expect(cut, isEmpty);
    });

    testWidgets('при обычном шрифте подписи не уменьшаются', (tester) async {
      await pumpCard(tester, AppLanguage.ru, 1.0, 0);
      final center = find.byKey(const ValueKey('donut_center'));
      final content =
          find.descendant(of: center, matching: find.byType(Column));
      expect(tester.getSize(center), tester.getSize(content));
    });
  });
}
