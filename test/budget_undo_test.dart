import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/add_budget_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отложенное удаление лимитов и операций (блок `fix/budget-undo`) на
/// настоящей базе ObjectBox.

Budget _budget({
  required int month,
  String? serverId,
  double limit = 100,
  Category category = Category.food,
  int year = 2032,
}) =>
    Budget(
      serverId: serverId,
      dbCategory: category.name,
      limitAmount: limit,
      currencyCode: 'USD',
      month: month,
      year: year,
      spent: 0,
      remaining: limit,
    );

Transaction _expense({
  required DateTime date,
  required double amount,
  Category category = Category.food,
}) =>
    Transaction(
      amount: amount,
      description: 'Кофе',
      dbCategory: category.name,
      dbType: TransactionType.expense.name,
      dateMilliseconds: date.millisecondsSinceEpoch,
      dateCreatedMilliseconds: date.millisecondsSinceEpoch,
      currencyCode: 'USD',
      baseAmount: amount,
    );

/// Открывает [sheet] отдельным маршрутом, чтобы `Navigator.pop` после
/// сохранения закрывал форму, а не корневой экран.
Future<void> _pumpSheet(WidgetTester tester, Widget sheet) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: sheet),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDbService db;

  setUpAll(() async {
    LanguageManager.initFallback();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await CurrencyFormatter.setCurrency(Currency.usd);
    tempDir = await Directory.systemTemp.createTemp('budget_undo_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
    await LocalDbService.init();
    db = LocalDbService.instance;
  });

  tearDown(() {
    // Очереди общие на всё приложение — тест не должен оставлять в них
    // записи и таймеры.
    UndoableDeletions.budgets.undoWhere((_) => true);
    UndoableDeletions.transactions.undoWhere((_) => true);
  });

  List<Budget> foodBudgets(int month) => db
      .getBudgetsForPeriod(month, 2032)
      .where((b) => b.category == Category.food)
      .toList();

  group('LOGIC-06: новый лимит вместо только что удалённого', () {
    testWidgets(
        'удалил «Питание» свайпом → сразу создал «Питание»: новый лимит '
        'виден и не удаляется через 5 секунд', (tester) async {
      db.saveBudget(_budget(month: 1, serverId: 'srv-food-1', limit: 100));
      final swiped = foodBudgets(1).single;
      UndoableDeletions.budgets.schedule(swiped);

      // Экран лимитов не передаёт скрытый лимит в limitedCategories, поэтому
      // «Питание» снова доступно и выбрано по умолчанию
      await _pumpSheet(
        tester,
        AddBudgetSheet(selectedMonth: 1, selectedYear: 2032, onSaved: () {}),
      );
      await tester.enterText(find.byType(TextField).first, '250');
      final save = find.text(LanguageManager.l10n.save_btn);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(UndoableDeletions.budgets.isPending(swiped), isFalse,
          reason: 'новый лимит ляжет в ту же строку — она не должна быть '
              'скрыта');

      await tester.pump(const Duration(seconds: 6));

      final saved = foodBudgets(1).single;
      expect(saved.localId, swiped.localId);
      expect(saved.limitAmount, 250);
      expect(saved.serverId, 'srv-food-1',
          reason: 'сервер обновит ту же запись, а не удалит её');
      expect(saved.isModified, isTrue, reason: 'новая сумма уйдёт на сервер');
    });

    test('ожидающее удаление лимита другой категории или месяца не трогается',
        () {
      db.saveBudget(_budget(month: 2, category: Category.transport));
      db.saveBudget(_budget(month: 3));
      final transport = db.getBudgetsForPeriod(2, 2032).single;
      final march = foodBudgets(3).single;
      UndoableDeletions.budgets
        ..schedule(transport)
        ..schedule(march);

      final undone = UndoableDeletions.budgets.undoWhere((b) =>
          b.dbCategory == Category.food.name && b.month == 2 && b.year == 2032);

      expect(undone, isFalse);
      expect(UndoableDeletions.budgets.isPending(transport), isTrue);
      expect(UndoableDeletions.budgets.isPending(march), isTrue);
    });

    test('новый лимит поверх синхронизированной строки сохраняет её serverId',
        () {
      db.saveBudget(_budget(month: 4, serverId: 'srv-food-4'));

      db.saveBudget(_budget(month: 4, limit: 300));

      final saved = foodBudgets(4).single;
      expect(saved.limitAmount, 300);
      expect(saved.serverId, 'srv-food-4');
      expect(saved.isModified, isTrue);
    });
  });

  group('LOGIC-07.2: скрытая операция не учитывается до удаления', () {
    test('расходы по категориям для лимитов — без скрытой операции', () {
      db.addTransaction(_expense(date: DateTime(2032, 5, 3), amount: 40));
      db.addTransaction(_expense(date: DateTime(2032, 5, 4), amount: 60));
      final hidden = db
          .getTransactionsForPeriod(5, 2032)
          .firstWhere((t) => t.amount == 60);
      UndoableDeletions.transactions.schedule(hidden);

      final visible = db
          .getTransactionsForPeriod(5, 2032)
          .where((t) => !UndoableDeletions.transactions.isPending(t));

      expect(db.getCategoryExpensesForPeriod(5, 2032)[Category.food], 100);
      expect(db.categoryExpensesFor(visible)[Category.food], 40);
    });

    test('экспорт отчёта не включает скрытую операцию и её трату в лимит', () {
      db.saveBudget(_budget(month: 6, limit: 500));
      db.addTransaction(_expense(date: DateTime(2032, 6, 3), amount: 70));
      db.addTransaction(_expense(date: DateTime(2032, 6, 4), amount: 30));
      final hidden = db
          .getTransactionsForPeriod(6, 2032)
          .firstWhere((t) => t.amount == 30);
      UndoableDeletions.transactions.schedule(hidden);

      final report = ReportDataService(db: db)
          .build(ReportPeriod.month(6, 2032), currency: Currency.usd);

      expect(report.transactions.map((t) => t.amount), [70]);
      expect(report.budgetLines.single.spent, 70);

      UndoableDeletions.transactions.undo(hidden);
      final restored = ReportDataService(db: db)
          .build(ReportPeriod.month(6, 2032), currency: Currency.usd);
      expect(restored.transactions, hasLength(2));
      expect(restored.budgetLines.single.spent, 100);
    });
  });
}
