import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Открывает форму поверх стартового экрана, чтобы `Navigator.pop` после
/// сохранения закрывал её, а не корневой маршрут. Без [settle] анимация
/// маршрута не прокручивается до конца.
Future<void> _pumpSheet(WidgetTester tester, {bool settle = true}) async {
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
                  builder: (_) => const Scaffold(body: AddTransactionSheet()),
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
  if (settle) await tester.pumpAndSettle();
}

bool _amountHasFocus(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).focusNode!.hasFocus;

/// Чип внутри [CategoryChip] с ключом [key].
ChoiceChip _chipFor(String key, WidgetTester tester) {
  return tester.widget<ChoiceChip>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(ChoiceChip),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 15, 18, 30);

  setUpAll(() {
    LanguageManager.initFallback();
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(
      Transaction(
        amount: 0,
        description: '',
        dbCategory: 'other',
        dbType: 'expense',
        dateMilliseconds: 0,
        dateCreatedMilliseconds: 0,
      ),
    );
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    EnvironmentConfig.clearListenersForTesting();
    dotenv.testLoad(fileInput: '''
PROD_API_BASE_URL=https://prod.example.com/api/v1
DEV_API_BASE_URL=https://dev.example.com/api/v1
API_BASE_URL=http://localhost:8000/api/v1
''');
    await EnvironmentConfig.init();
    AppInfoService.instance.reset();
    PackageInfo.setMockInitialValues(
      appName: 'FinanceApp',
      packageName: 'com.finance.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    LocalDbService.instance = null;
    EnvironmentConfig.clearListenersForTesting();
    AppInfoService.instance.reset();
  });

  group('TransactionDateSelector', () {
    testWidgets('по умолчанию выбран чип «Сегодня»', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        TransactionDateSelector(date: now, now: now, onChanged: (_) {}),
      ));

      final todayChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, LanguageManager.l10n.today),
      );
      expect(todayChip.selected, isTrue);
      expect(find.text(LanguageManager.l10n.pick_date), findsOneWidget);
    });

    testWidgets('«Вчера» возвращает предыдущий день без времени',
        (tester) async {
      DateTime? picked;
      await tester.pumpWidget(_buildTestApp(
        TransactionDateSelector(
          date: now,
          now: now,
          onChanged: (d) => picked = d,
        ),
      ));

      await tester.tap(find.text(LanguageManager.l10n.yesterday));
      await tester.pump();

      expect(picked, DateTime(2026, 10, 14));
    });

    testWidgets('произвольная дата показывается в третьем чипе и выбрана',
        (tester) async {
      final custom = DateTime(2026, 10, 1);
      await tester.pumpWidget(_buildTestApp(
        TransactionDateSelector(date: custom, now: now, onChanged: (_) {}),
      ));

      final label = LanguageManager.formatDayMonth(custom);
      final customChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
      expect(customChip.selected, isTrue);
      expect(find.text(LanguageManager.l10n.pick_date), findsNothing);
    });

    testWidgets('чип календаря открывает выбор даты', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        TransactionDateSelector(date: now, now: now, onChanged: (_) {}),
      ));

      await tester.tap(find.text(LanguageManager.l10n.pick_date));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('CategoryChipsSelector', () {
    test('orderByFrequency ставит частые первыми и игнорирует чужие', () {
      final ordered = CategoryChipsSelector.orderByFrequency(
        Category.expenseCategories,
        [Category.shopping, Category.salary, Category.transport],
      );

      expect(ordered.take(2), [Category.shopping, Category.transport]);
      expect(ordered, isNot(contains(Category.salary)));
      expect(ordered.toSet(), Category.expenseCategories.toSet());
      expect(ordered.length, Category.expenseCategories.length);
    });

    test('visibleCategories ограничивает число и сохраняет выбранную', () {
      const ordered = Category.expenseCategories;

      final withSelected =
          CategoryChipsSelector.visibleCategories(ordered, Category.food, 5);
      expect(withSelected, ordered.take(5).toList());

      final selectedHidden =
          CategoryChipsSelector.visibleCategories(ordered, Category.other, 5);
      expect(selectedHidden.length, 5);
      expect(selectedHidden.first, Category.other);
      expect(selectedHidden.skip(1), ordered.take(4));

      final shortList = CategoryChipsSelector.visibleCategories(
        ordered.take(6).toList(),
        Category.food,
        5,
      );
      expect(shortList.length, 6);
    });

    testWidgets('показывает частые категории и чип «Ещё»', (tester) async {
      Category? selected;
      await tester.pumpWidget(_buildTestApp(
        CategoryChipsSelector(
          categories: Category.expenseCategories,
          frequent: const [Category.shopping, Category.transport],
          selected: Category.food,
          onSelected: (c) => selected = c,
        ),
      ));

      for (final category in [
        Category.shopping,
        Category.transport,
        Category.food,
        Category.entertainment,
        Category.health,
      ]) {
        expect(
          find.byKey(ValueKey('category_chip_${category.name}')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('category_chip_subscriptions')),
          findsNothing);
      expect(find.byKey(const ValueKey('category_chip_more')), findsOneWidget);
      expect(_chipFor('category_chip_food', tester).selected, isTrue);

      await tester.tap(find.byKey(const ValueKey('category_chip_transport')));
      await tester.pump();

      expect(selected, Category.transport);
    });

    testWidgets('«Ещё» открывает все категории и возвращает выбор',
        (tester) async {
      Category? selected;
      await tester.pumpWidget(_buildTestApp(
        CategoryChipsSelector(
          categories: Category.expenseCategories,
          selected: Category.food,
          onSelected: (c) => selected = c,
        ),
      ));

      await tester.tap(find.byKey(const ValueKey('category_chip_more')));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      expect(find.text(LanguageManager.l10n.all_categories), findsOneWidget);
      for (final category in Category.expenseCategories) {
        expect(
          find.byKey(ValueKey('category_sheet_${category.name}')),
          findsOneWidget,
        );
      }
      // Поиск появляется только для длинного списка.
      expect(find.byIcon(Icons.search_rounded), findsNothing);

      await tester.tap(find.byKey(const ValueKey('category_sheet_other')));
      await tester.pumpAndSettle();

      expect(selected, Category.other);
      expect(find.byType(CategoryPickerSheet), findsNothing);
    });
  });

  group('TransactionTypeToggle', () {
    testWidgets('переключение на «Доход» передаёт income', (tester) async {
      TransactionType? type;
      await tester.pumpWidget(_buildTestApp(
        TransactionTypeToggle(
          type: TransactionType.expense,
          onChanged: (t) => type = t,
        ),
      ));

      await tester.tap(find.text(LanguageManager.l10n.income_title));
      await tester.pump();

      expect(type, TransactionType.income);
    });
  });

  group('AddTransactionSheet', () {
    testWidgets('при смене типа меняется набор категорий', (tester) async {
      await _pumpSheet(tester);

      expect(find.byKey(const ValueKey('category_chip_food')), findsOneWidget);
      expect(find.byKey(const ValueKey('category_chip_salary')), findsNothing);

      await tester.tap(find.text(LanguageManager.l10n.income_title));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('category_chip_food')), findsNothing);
      expect(_chipFor('category_chip_salary', tester).selected, isTrue);
    });

    testWidgets('сохраняет операцию вчерашним днём и выбранной категорией',
        (tester) async {
      final mockDb = _MockLocalDbService();
      when(() => mockDb.saveTransaction(any())).thenReturn(null);
      when(() => mockDb.getFrequentCategories(any()))
          .thenReturn(const [Category.transport]);
      LocalDbService.instance = mockDb;

      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, '24000');
      await tester.tap(find.text(LanguageManager.l10n.yesterday));
      await tester.pump();
      final transportChip =
          find.byKey(const ValueKey('category_chip_transport'));
      await tester.ensureVisible(transportChip);
      await tester.tap(transportChip);
      await tester.pump();

      final addButton = find.text(LanguageManager.l10n.add_btn);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final saved = verify(() => mockDb.saveTransaction(captureAny()))
          .captured
          .single as Transaction;
      final expectedDay =
          DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      expect(DateUtils.isSameDay(saved.date, expectedDay), isTrue);
      expect(saved.category, Category.transport);
      expect(saved.type, TransactionType.expense);
      expect(find.byType(AddTransactionSheet), findsNothing);
    });

    testWidgets('фокус суммы ставится после выезда формы, а не во время',
        (tester) async {
      final mockDb = _MockLocalDbService();
      when(() => mockDb.getFrequentCategories(any())).thenReturn(const []);
      LocalDbService.instance = mockDb;

      await _pumpSheet(tester, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_amountHasFocus(tester), isFalse);

      await tester.pumpAndSettle();
      expect(_amountHasFocus(tester), isTrue);
    });

    testWidgets('пустая сумма не сохраняет операцию', (tester) async {
      final mockDb = _MockLocalDbService();
      when(() => mockDb.getFrequentCategories(any())).thenReturn(const []);
      LocalDbService.instance = mockDb;

      await _pumpSheet(tester);

      final addButton = find.text(LanguageManager.l10n.add_btn);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();

      verifyNever(() => mockDb.saveTransaction(any()));
      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsOneWidget);
    });
  });
}
