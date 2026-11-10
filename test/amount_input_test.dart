import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/add_budget_sheet.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

/// Открывает [sheet] отдельным маршрутом, чтобы `Navigator.pop` после
/// сохранения закрывал форму, а не корневой экран.
Future<void> _pumpSheet(
  WidgetTester tester,
  Widget sheet, {
  Locale locale = const Locale('ru'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
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

String _amountText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Future<void> _tap(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

final _submitTransaction = find.byKey(const ValueKey('add_transaction_submit'));

Transaction _transaction(double amount, Currency currency) => Transaction(
      localId: 7,
      serverId: 'tx-1',
      amount: amount,
      description: 'Подписка',
      dbCategory: 'other',
      dbType: 'expense',
      currencyCode: currency.code,
      dateMilliseconds: DateTime(2026, 11, 3, 10).millisecondsSinceEpoch,
      dateCreatedMilliseconds: DateTime(2026, 11, 3, 10).millisecondsSinceEpoch,
    );

Budget _budget(double limit, Currency currency) => Budget(
      localId: 3,
      serverId: 'budget-1',
      dbCategory: Category.food.name,
      limitAmount: limit,
      currencyCode: currency.code,
      month: 11,
      year: 2026,
      spent: 0,
      remaining: limit,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLocalDbService mockDb;

  setUpAll(() {
    LanguageManager.initFallback();
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(Currency.usd);
    registerFallbackValue(_transaction(0, Currency.usd));
    registerFallbackValue(_budget(0, Currency.usd));
  });

  /// База валюты ставится до подмены базы данных: `setCurrency` трогает
  /// `LocalDbService`, если она инициализирована.
  Future<void> setUpEnvironment({
    required Currency base,
    AppLanguage language = AppLanguage.ru,
  }) async {
    LanguageManager.setLanguage(language, save: false);
    await CurrencyFormatter.setCurrency(base);
    mockDb = _MockLocalDbService();
    when(() => mockDb.getFrequentCategories(any())).thenReturn(const []);
    when(() => mockDb.getRecurringPayments()).thenReturn(const []);
    when(() => mockDb.saveTransaction(any())).thenReturn(null);
    when(() => mockDb.saveBudget(any())).thenReturn(null);
    when(() => mockDb.getSpentForCategory(any(), any(), any(), any()))
        .thenReturn(0);
    LocalDbService.instance = mockDb;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    LocalDbService.instance = null;
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await CurrencyFormatter.setCurrency(Currency.usd);
  });

  Transaction savedTransaction() =>
      verify(() => mockDb.saveTransaction(captureAny())).captured.single
          as Transaction;

  Budget savedBudget() =>
      verify(() => mockDb.saveBudget(captureAny())).captured.single as Budget;

  group('Правка операции в валюте, отличной от базовой', () {
    testWidgets('база UZS, операция \$19.99: копейки не теряются',
        (tester) async {
      await setUpEnvironment(base: Currency.uzs);
      await _pumpSheet(
        tester,
        AddTransactionSheet(
            transactionToEdit: _transaction(19.99, Currency.usd)),
      );

      expect(_amountText(tester), '19,99');

      await _tap(tester, _submitTransaction);

      final saved = savedTransaction();
      expect(saved.amount, 19.99);
      expect(saved.currencyCode, 'USD');
      expect(saved.serverId, 'tx-1');
    });

    testWidgets('база UZS, операция \$0.45 не превращается в 0',
        (tester) async {
      await setUpEnvironment(base: Currency.uzs);
      await _pumpSheet(
        tester,
        AddTransactionSheet(
            transactionToEdit: _transaction(0.45, Currency.usd)),
      );

      expect(_amountText(tester), '0,45');

      await _tap(tester, _submitTransaction);

      expect(savedTransaction().amount, 0.45);
    });

    testWidgets('база USD, операция в UZS: без копеек и сохраняется как есть',
        (tester) async {
      await setUpEnvironment(base: Currency.usd);
      await _pumpSheet(
        tester,
        AddTransactionSheet(
            transactionToEdit: _transaction(50000, Currency.uzs)),
      );

      expect(_amountText(tester), '50 000');

      await _tap(tester, _submitTransaction);

      final saved = savedTransaction();
      expect(saved.amount, 50000);
      expect(saved.currencyCode, 'UZS');
    });

    testWidgets('ошибка максимума — в формате валюты операции', (tester) async {
      await setUpEnvironment(base: Currency.usd);
      await _pumpSheet(
        tester,
        AddTransactionSheet(
            transactionToEdit: _transaction(50000, Currency.uzs)),
      );

      await tester.enterText(find.byType(TextField).first, '999999999999');
      await _tap(tester, _submitTransaction);

      verifyNever(() => mockDb.saveTransaction(any()));
      expect(
        find.text(LanguageManager.l10n
            .amount_requirement_max('100 000 000 000', 'UZS')),
        findsOneWidget,
      );
    });
  });

  group('EN-локаль: сохранение без правки суммы', () {
    testWidgets('операция 1 500 UZS не делится на 1000', (tester) async {
      await setUpEnvironment(base: Currency.uzs, language: AppLanguage.en);
      await _pumpSheet(
        tester,
        AddTransactionSheet(
            transactionToEdit: _transaction(1500, Currency.uzs)),
        locale: const Locale('en'),
      );

      expect(_amountText(tester), '1 500');

      await _tap(tester, _submitTransaction);

      expect(savedTransaction().amount, 1500);
    });

    testWidgets('операция \$1,500.00 открывается и сохраняется',
        (tester) async {
      await setUpEnvironment(base: Currency.usd, language: AppLanguage.en);
      await _pumpSheet(
        tester,
        AddTransactionSheet(
            transactionToEdit: _transaction(1500, Currency.usd)),
        locale: const Locale('en'),
      );

      expect(_amountText(tester), '1 500,00');

      // Ввод копеек в подставленную сумму не блокируется
      await tester.enterText(find.byType(TextField).first, '1 500,5');
      expect(_amountText(tester), '1 500,5');

      await _tap(tester, _submitTransaction);

      expect(savedTransaction().amount, 1500.5);
    });

    testWidgets('лимит 1 500 000 UZS сохраняется без изменений',
        (tester) async {
      await setUpEnvironment(base: Currency.uzs, language: AppLanguage.en);
      await _pumpSheet(
        tester,
        AddBudgetSheet(
          selectedMonth: 11,
          selectedYear: 2026,
          budgetToEdit: _budget(1500000, Currency.uzs),
          onSaved: () {},
        ),
        locale: const Locale('en'),
      );

      expect(_amountText(tester), '1 500 000');

      await _tap(tester, find.text(LanguageManager.l10n.save_btn));

      final saved = savedBudget();
      expect(saved.limitAmount, 1500000);
      expect(saved.currencyCode, 'UZS');
    });

    testWidgets('смена валюты лимита подставляет сумму в формате поля',
        (tester) async {
      await setUpEnvironment(base: Currency.usd, language: AppLanguage.en);
      await _pumpSheet(
        tester,
        AddBudgetSheet(
          selectedMonth: 11,
          selectedYear: 2026,
          budgetToEdit: _budget(1000, Currency.usd),
          onSaved: () {},
        ),
        locale: const Locale('en'),
      );

      await tester.tap(find.byType(CurrencyBadge));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Currency.uzs.localizedName));
      await tester.pumpAndSettle();

      final converted = CurrencyExchangeService.instance
          .convert(1000, from: Currency.usd, to: Currency.uzs);
      expect(_amountText(tester),
          CurrencyFormatter.formatForInput(converted, Currency.uzs));
      expect(_amountText(tester), isNot(contains(',')));

      await _tap(tester, find.text(LanguageManager.l10n.save_btn));

      expect(savedBudget().limitAmount, converted.roundToDouble());
    });
  });
}
