import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Budget _budget(Category category, double limit, {int month = 10}) => Budget(
      dbCategory: category.name,
      limitAmount: limit,
      month: month,
      year: 2026,
      spent: 0,
      remaining: limit,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.usd);
  });

  // 16 октября: до конца месяца 16 дней, включая сегодня
  final now = DateTime(2026, 10, 16, 12);
  const october = MonthPeriod(2026, 10);

  group('MonthBudgetSummary', () {
    test('текущий месяц: остаток делится на оставшиеся дни', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: [
          _budget(Category.food, 2000),
          _budget(Category.transport, 400),
        ],
        spentByCategory: {
          Category.food: 600,
          Category.transport: 200,
          // Траты без лимита в сводку не входят
          Category.shopping: 5000,
        },
        period: october,
        now: now,
      );

      expect(summary.periodState, BudgetPeriodState.current);
      expect(summary.totalLimit, 2400);
      expect(summary.totalSpent, 800);
      expect(summary.remaining, 1600);
      expect(summary.daysLeft, 16);
      expect(summary.dailyAllowance, 100);
      expect(summary.isExceeded, isFalse);
    });

    test('перерасход: в день — 0, остаток отрицательный', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: [_budget(Category.food, 1000)],
        spentByCategory: {Category.food: 1300},
        period: october,
        now: now,
      );

      expect(summary.isExceeded, isTrue);
      expect(summary.remaining, -300);
      expect(summary.dailyAllowance, 0);
    });

    test('прошлый и будущий месяцы: без расчёта на день', () {
      final past = MonthBudgetSummary.calculate(
        budgets: [_budget(Category.food, 1000, month: 9)],
        spentByCategory: {Category.food: 400},
        period: const MonthPeriod(2026, 9),
        now: now,
      );
      final future = MonthBudgetSummary.calculate(
        budgets: [_budget(Category.food, 1000, month: 11)],
        spentByCategory: const {},
        period: const MonthPeriod(2026, 11),
        now: now,
      );

      expect(past.periodState, BudgetPeriodState.past);
      expect(past.daysLeft, 0);
      expect(past.dailyAllowance, 0);
      expect(future.periodState, BudgetPeriodState.future);
      expect(future.dailyAllowance, 0);
    });

    test('последний день месяца: остался один день', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: [_budget(Category.food, 1000)],
        spentByCategory: {Category.food: 400},
        period: october,
        now: DateTime(2026, 10, 31, 23),
      );

      expect(summary.daysLeft, 1);
      expect(summary.dailyAllowance, 600);
    });

    test('без лимитов — hasLimits = false', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: const [],
        spentByCategory: {Category.food: 400},
        period: october,
        now: now,
      );

      expect(summary.hasLimits, isFalse);
    });
  });

  group('MonthBudgetCard', () {
    testWidgets('без лимитов показывает призыв и вызывает добавление',
        (tester) async {
      var added = false;
      await tester.pumpWidget(_buildTestApp(MonthBudgetCard(
        summary: MonthBudgetSummary.calculate(
          budgets: const [],
          spentByCategory: const {},
          period: october,
          now: now,
        ),
        onAddLimit: () => added = true,
      )));

      expect(
          find.text(LanguageManager.l10n.month_budget_title), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('month_budget_add_limit')));
      expect(added, isTrue);
    });

    testWidgets('текущий месяц: сумма в день и оставшиеся дни', (tester) async {
      final summary = MonthBudgetSummary.calculate(
        budgets: [_budget(Category.food, 2000)],
        spentByCategory: {Category.food: 400},
        period: october,
        now: now,
      );
      await tester.pumpWidget(_buildTestApp(
        MonthBudgetCard(summary: summary, onAddLimit: () {}),
      ));

      expect(find.text(LanguageManager.l10n.daily_allowance), findsOneWidget);
      expect(find.text(CurrencyFormatter.format(100)), findsOneWidget);
      expect(find.text(LanguageManager.l10n.days_left(16)), findsOneWidget);
      expect(find.text(LanguageManager.l10n.budget_remaining), findsOneWidget);
    });

    testWidgets('перерасход в текущем месяце показывает сумму перерасхода',
        (tester) async {
      final summary = MonthBudgetSummary.calculate(
        budgets: [_budget(Category.food, 1000)],
        spentByCategory: {Category.food: 1300},
        period: october,
        now: now,
      );
      await tester.pumpWidget(_buildTestApp(
        MonthBudgetCard(summary: summary, onAddLimit: () {}),
      ));

      // Заголовок и плашка остатка — «Перерасход»
      expect(
          find.text(LanguageManager.l10n.budget_overspent), findsNWidgets(2));
      expect(find.text(LanguageManager.l10n.daily_allowance), findsNothing);
      expect(find.text(CurrencyFormatter.format(300)), findsNWidgets(2));
    });
  });

  group('BudgetItemCard', () {
    Future<void> pumpCard(WidgetTester tester, double spent) async {
      await tester.pumpWidget(_buildTestApp(BudgetItemCard(
        budget: _budget(Category.food, 1000),
        currentSpent: spent,
        isFirst: false,
        showSwipeHint: false,
        onTap: () {},
        onDelete: () {},
        onHintShown: () {},
      )));
    }

    Color barColor(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .color!;

    testWidgets('в пределах лимита: остаток, «из», процент, основной цвет',
        (tester) async {
      await pumpCard(tester, 300);

      expect(find.text(CurrencyFormatter.format(700)), findsOneWidget);
      expect(
        find.text(LanguageManager.l10n.budget_spent_of(
          CurrencyFormatter.format(300),
          CurrencyFormatter.format(1000),
        )),
        findsOneWidget,
      );
      expect(find.text('30%'), findsOneWidget);
      expect(barColor(tester), AppTheme.lightTheme.colorScheme.primary);
    });

    testWidgets('от 75% — цвет предупреждения', (tester) async {
      await pumpCard(tester, 800);

      expect(find.text('80%'), findsOneWidget);
      expect(barColor(tester), isNot(AppTheme.lightTheme.colorScheme.primary));
      expect(find.textContaining(LanguageManager.l10n.budget_exceeded),
          findsNothing);
    });

    testWidgets('сверх лимита — «Превышен на» и процент больше 100',
        (tester) async {
      await pumpCard(tester, 1250);

      expect(
        find.text('${LanguageManager.l10n.budget_exceeded} '
            '${CurrencyFormatter.format(250)}'),
        findsOneWidget,
      );
      expect(find.text('125%'), findsOneWidget);
    });
  });
}
