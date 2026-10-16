import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/category_style.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Transaction _tx({
  required int id,
  required double amount,
  required TransactionType type,
  required Category category,
  required DateTime date,
  String description = '',
}) {
  return Transaction(
    localId: id,
    amount: amount,
    description: description,
    dbCategory: category.name,
    dbType: type.name,
    dateMilliseconds: date.millisecondsSinceEpoch,
    dateCreatedMilliseconds: date.millisecondsSinceEpoch,
    currencyCode: 'USD',
    baseAmount: amount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.usd);
  });

  final oct14 = DateTime(2026, 10, 14, 12);
  final oct15 = DateTime(2026, 10, 15, 9);
  final oct15late = DateTime(2026, 10, 15, 20);

  group('DayGroupWidget.groupByDay', () {
    test('новые дни сверху, порядок внутри дня сохраняется', () {
      final a = _tx(
          id: 1,
          amount: 10,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15late);
      final b = _tx(
          id: 2,
          amount: 20,
          type: TransactionType.expense,
          category: Category.transport,
          date: oct15);
      final c = _tx(
          id: 3,
          amount: 30,
          type: TransactionType.expense,
          category: Category.food,
          date: oct14);

      final grouped = DayGroupWidget.groupByDay([a, b, c]);

      expect(grouped.keys.toList(),
          [DateTime(2026, 10, 15), DateTime(2026, 10, 14)]);
      expect(grouped[DateTime(2026, 10, 15)], [a, b]);
    });

    test('следующая страница дописывается к уже загруженному дню', () {
      final first = _tx(
          id: 1,
          amount: 10,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15late);
      final second = _tx(
          id: 2,
          amount: 20,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15);

      final page1 = DayGroupWidget.groupByDay([first]);
      final page2 = DayGroupWidget.groupByDay([second], appendTo: page1);

      expect(page2[DateTime(2026, 10, 15)], [first, second]);
      // Исходная страница не изменилась
      expect(page1[DateTime(2026, 10, 15)], [first]);
    });
  });

  group('CategoryMonthSummary.fromTransactions', () {
    test('итоги категорий в базовой валюте, крупные сверху', () {
      final summaries = CategoryMonthSummary.fromTransactions([
        _tx(
            id: 1,
            amount: 30,
            type: TransactionType.expense,
            category: Category.food,
            date: oct15),
        _tx(
            id: 2,
            amount: 20,
            type: TransactionType.expense,
            category: Category.food,
            date: oct14),
        _tx(
            id: 3,
            amount: 10,
            type: TransactionType.expense,
            category: Category.transport,
            date: oct15),
        _tx(
            id: 4,
            amount: 500,
            type: TransactionType.income,
            category: Category.salary,
            date: oct14),
      ]);

      expect(summaries.map((s) => s.category).toList(),
          [Category.salary, Category.food, Category.transport]);
      expect(summaries[0].total, 500);
      expect(summaries[1].total, -50);
      expect(summaries[1].transactions.length, 2);
    });
  });

  group('CategoryMonthGroup', () {
    testWidgets('свёрнута по умолчанию, по тапу показывает операции с датами',
        (tester) async {
      final summary = CategoryMonthSummary.fromTransactions([
        _tx(
            id: 1,
            amount: 30,
            type: TransactionType.expense,
            category: Category.food,
            date: oct15,
            description: 'Обед'),
        _tx(
            id: 2,
            amount: 20,
            type: TransactionType.expense,
            category: Category.food,
            date: oct14),
      ]).single;

      await tester.pumpWidget(_buildTestApp(CategoryMonthGroup(
        summary: summary,
        onTransactionTap: (_) {},
        onTransactionDelete: (_) {},
      )));

      expect(find.text('Питание'), findsOneWidget);
      expect(find.text('2 операции'), findsOneWidget);
      expect(find.byType(TransactionItemTile), findsNothing);

      await tester.tap(find.byKey(const ValueKey('category_group_food')));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionItemTile), findsNWidgets(2));
      // Дата в заголовке строки, описание — под ней
      expect(find.text('Обед'), findsOneWidget);
      expect(find.text(LanguageManager.formatDayMonth(oct15)), findsOneWidget);
      expect(find.text(LanguageManager.formatDayMonth(oct14)), findsOneWidget);
      // Иконка категории только в заголовке группы, не в строках
      expect(
        find.descendant(
          of: find.byType(TransactionItemTile),
          matching: find.byIcon(CategoryStyle.icon(Category.food)),
        ),
        findsNothing,
      );
    });
  });

  group('DashboardViewSwitcher', () {
    testWidgets('переключает режим', (tester) async {
      DashboardViewMode? selected;
      await tester.pumpWidget(_buildTestApp(DashboardViewSwitcher(
        mode: DashboardViewMode.days,
        onChanged: (mode) => selected = mode,
      )));

      // Раздельные кнопки только с текстом
      expect(
        find.descendant(
          of: find.byType(DashboardViewSwitcher),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      await tester.tap(find.text(LanguageManager.l10n.view_by_categories));
      await tester.pump();

      expect(selected, DashboardViewMode.categories);
    });
  });

  group('TransactionDetailsSheet', () {
    const longText = 'Продукты в Korzinka на неделю: овощи, фрукты, молоко, '
        'хлеб и подарок для мамы на день рождения';

    Future<void> openSheet(WidgetTester tester, Transaction transaction) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  TransactionDetailsSheet.show(context, transaction),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('показывает полное описание, категорию и дату со временем',
        (tester) async {
      final t = _tx(
          id: 1,
          amount: 30,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15,
          description: longText);

      await openSheet(tester, t);

      final description = tester.widget<SelectableText>(
        find.byKey(const ValueKey('transaction_details_description')),
      );
      expect(description.data, longText);
      expect(find.text('Питание'), findsOneWidget);
      expect(find.text(LanguageManager.formatDateTime(oct15)), findsOneWidget);
      // В основной валюте — строк пересчёта нет
      expect(find.text(LanguageManager.l10n.details_original_amount),
          findsNothing);
    });

    testWidgets('для иностранной валюты показывает сумму чека и пересчёт',
        (tester) async {
      final now = oct15.millisecondsSinceEpoch;
      final foreign = Transaction(
        localId: 7,
        amount: 1000000,
        description: 'Кинотеатр',
        dbCategory: Category.entertainment.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: now,
        dateCreatedMilliseconds: now,
        currencyCode: 'UZS',
        exchangeRate: 1 / 12800.0,
        baseAmount: 78.125,
      );

      await openSheet(tester, foreign);

      expect(find.text(LanguageManager.l10n.details_original_amount),
          findsOneWidget);
      expect(find.text(LanguageManager.l10n.details_in_base_currency),
          findsOneWidget);
    });

    testWidgets('кнопки возвращают действие и закрывают карточку',
        (tester) async {
      final t = _tx(
          id: 1,
          amount: 30,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15);

      TransactionDetailsAction? result;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await TransactionDetailsSheet.show(context, t),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transaction_details_edit')));
      await tester.pumpAndSettle();
      expect(result, TransactionDetailsAction.edit);
      expect(find.byType(TransactionDetailsSheet), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('transaction_details_delete')));
      await tester.pumpAndSettle();
      expect(result, TransactionDetailsAction.delete);
    });
  });

  group('TransactionItemTile', () {
    testWidgets('описание выводится одной строкой под категорией',
        (tester) async {
      final t = _tx(
          id: 1,
          amount: 30,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15,
          description: 'Длинное описание операции');

      await tester.pumpWidget(_buildTestApp(TransactionItemTile(
        transaction: t,
        onTap: () {},
        onDelete: () {},
      )));

      final description =
          tester.widget<Text>(find.text('Длинное описание операции'));
      expect(description.maxLines, 1);
      expect(description.overflow, TextOverflow.ellipsis);
      expect(description.style?.fontSize, AppFontSize.hint);
      expect(
        tester.getTopLeft(find.text('Питание')).dy,
        lessThan(tester.getTopLeft(find.text('Длинное описание операции')).dy),
      );
      expect(find.byIcon(CategoryStyle.icon(Category.food)), findsOneWidget);
    });

    testWidgets('без описания — только категория', (tester) async {
      final t = _tx(
          id: 1,
          amount: 30,
          type: TransactionType.expense,
          category: Category.food,
          date: oct15);

      await tester.pumpWidget(_buildTestApp(TransactionItemTile(
        transaction: t,
        onTap: () {},
        onDelete: () {},
      )));

      expect(find.text('Питание'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });
  });
}
