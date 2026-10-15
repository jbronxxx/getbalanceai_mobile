import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';

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

    // Бейдж перерасхода с восклицательным знаком и процентом
    expect(find.text('! 150%'), findsOneWidget);
    expect(find.text('150%'), findsWidgets);
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
    // Плейсхолдер отсутствия транзакций
    expect(find.text(LanguageManager.l10n.no_transactions), findsOneWidget);
  });

  testWidgets('Кейс: группировка при более чем 3 категориях (+N ещё)',
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

    // Топ-2 должны присутствовать
    expect(find.text(Category.food.getLocalizedName()), findsOneWidget);
    expect(find.text(Category.transport.getLocalizedName()), findsOneWidget);
    // Оставшиеся 3 категории сворачиваются в строку «ещё 3 категории»
    expect(find.text('ещё 3 категории'), findsOneWidget);
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
}
