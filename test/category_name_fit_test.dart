import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_fonts.dart';

/// UX-15: в строке операции на «Балансе» и в карточке лимита на «Бюджете»
/// название категории видно целиком и при крупном шрифте (не «Пита…»,
/// «Здор…»), а длинная сумма в сумах уменьшается.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    await loadAppFonts();
  });

  setUp(() => CurrencyFormatter.setCurrency(Currency.uzs));
  tearDown(() {
    CurrencyFormatter.setCurrency(Currency.usd);
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
  });

  Transaction tx(Category category, double amount) => Transaction(
        localId: 1,
        amount: amount,
        description: 'Обед с коллегами в кафе у офиса',
        dbCategory: category.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime(2026, 11, 9).millisecondsSinceEpoch,
        dateCreatedMilliseconds: 0,
        currencyCode: 'UZS',
        baseAmount: amount,
      );

  Future<void> pumpRow(
    WidgetTester tester,
    Widget row,
    AppLanguage language,
    double scale,
  ) async {
    LanguageManager.setLanguage(language, save: false);
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: Locale(language.name),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              row,
            ],
          ),
        ),
      ),
    ));
  }

  /// Строка в карточке дня: экран 360 dp, поля списка по 16.
  Future<void> pumpTile(
    WidgetTester tester,
    Transaction transaction,
    AppLanguage language,
    double scale,
  ) =>
      pumpRow(
        tester,
        TransactionItemTile(
          transaction: transaction,
          onTap: () {},
          onDelete: () {},
        ),
        language,
        scale,
      );

  /// Карточка лимита на «Бюджете»: та же ширина экрана.
  Future<void> pumpBudget(
    WidgetTester tester,
    Category category,
    double remaining,
    AppLanguage language,
    double scale,
  ) =>
      pumpRow(
        tester,
        BudgetItemCard(
          budget: Budget(
            dbCategory: category.name,
            limitAmount: remaining + 1000,
            currencyCode: 'UZS',
            month: 11,
            year: 2026,
            spent: 1000,
            remaining: remaining,
          ),
          currentSpent: 1000,
          isFirst: false,
          showSwipeHint: false,
          onTap: () {},
          onDelete: () {},
          onHintShown: () {},
        ),
        language,
        scale,
      );

  /// Во сколько раз уменьшено название (1 — не уменьшено).
  double titleFit(WidgetTester tester, String name) {
    final label = find.widgetWithText(OneLineLabel, name);
    final text = find.descendant(of: label, matching: find.byType(RichText));
    return tester.getSize(label).width /
        tester.renderObject<RenderParagraph>(text).size.width;
  }

  for (final scale in [1.0, 1.15, 1.3, 1.5]) {
    testWidgets('название категории видно целиком, шрифт ×$scale',
        (tester) async {
      final problems = <String>[];
      for (final language in AppLanguage.values) {
        for (final category in Category.expenseCategories) {
          for (final amount in [300000.0, 36191556.0]) {
            await pumpTile(tester, tx(category, amount), language, scale);
            final name = category.getLocalizedName(
                tester.element(find.byType(TransactionItemTile)));
            final fit = titleFit(tester, name);
            // При обычном шрифте не уменьшается; при крупном может слегка
            // уменьшиться, но остаётся не мельче, чем при обычном.
            final minFit = scale == 1.0 ? 0.999 : 1 / scale;
            if (fit < minFit) {
              problems.add('${language.name} «$name» при $amount: '
                  '×${(fit * scale).toStringAsFixed(2)}');
            }
          }
        }
      }
      expect(problems, isEmpty);
    });
  }

  for (final scale in [1.0, 1.15, 1.3, 1.5]) {
    testWidgets('лимит: название категории видно целиком, шрифт ×$scale',
        (tester) async {
      final problems = <String>[];
      for (final language in AppLanguage.values) {
        for (final category in Category.expenseCategories) {
          for (final remaining in [4343444.0, 36191556.0]) {
            await pumpBudget(tester, category, remaining, language, scale);
            final name = category
                .getLocalizedName(tester.element(find.byType(BudgetItemCard)));
            final fit = titleFit(tester, name);
            final minFit = scale == 1.0 ? 0.999 : 1 / scale;
            if (fit < minFit) {
              problems.add('${language.name} «$name» при $remaining: '
                  '×${(fit * scale).toStringAsFixed(2)}');
            }
          }
        }
      }
      expect(problems, isEmpty);
    });
  }

  testWidgets('обычная сумма при обычном шрифте не уменьшается',
      (tester) async {
    await pumpTile(
        tester, tx(Category.entertainment, 300000), AppLanguage.ru, 1.0);
    final amount = find
        .ancestor(
            of: find.textContaining('300'), matching: find.byType(FittedBox))
        .first;
    final text = find.descendant(of: amount, matching: find.byType(RichText));
    expect(
      tester.getSize(amount).width,
      closeTo(tester.renderObject<RenderParagraph>(text).size.width, 0.5),
    );
  });

  testWidgets('длинная сумма при ×1.5 уменьшается, а не обрезается',
      (tester) async {
    await pumpTile(tester, tx(Category.food, 999999999), AppLanguage.ru, 1.5);
    expect(tester.takeException(), isNull);
    final amount = find
        .ancestor(
            of: find.textContaining('999'), matching: find.byType(FittedBox))
        .first;
    final text = find.descendant(of: amount, matching: find.byType(RichText));
    expect(tester.getSize(amount).width,
        lessThan(tester.renderObject<RenderParagraph>(text).size.width));
    expect(
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse);
  });
}
