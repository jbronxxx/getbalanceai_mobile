import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';

/// Плитки «Доход / Расход» («Баланс», «Аналитика»): длинная сумма
/// уменьшается по ширине, но плитки остаются одной высоты.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.eur);
  });

  tearDown(() => CurrencyFormatter.setCurrency(Currency.usd));

  Future<void> pumpTiles(
    WidgetTester tester, {
    required double income,
    required double expense,
    required double scale,
  }) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          // Высота не ограничена, как в карточках «Баланса» и «Аналитики».
          child: Column(
            children: [
              IncomeExpenseTiles(income: income, expense: expense),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Size tileSize(WidgetTester tester, String label) => tester.getSize(find
      .ancestor(of: find.text(label), matching: find.byType(Container))
      .first);

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('плитки одной высоты при разных суммах, шрифт ×$scale',
        (tester) async {
      await pumpTiles(tester, income: 0, expense: 36191556, scale: scale);

      final income = tileSize(tester, LanguageManager.l10n.income_title);
      final expense = tileSize(tester, LanguageManager.l10n.expense_title);
      expect(expense.height, income.height,
          reason: 'плитка с длинной суммой не должна становиться ниже');
      expect(expense.width, income.width);
    });
  }

  testWidgets('высота плиток не зависит от длины суммы', (tester) async {
    await pumpTiles(tester, income: 0, expense: 0, scale: 1.5);
    final short = tileSize(tester, LanguageManager.l10n.expense_title);

    await pumpTiles(tester, income: 0, expense: 999999999, scale: 1.5);
    final long = tileSize(tester, LanguageManager.l10n.expense_title);

    expect(long.height, short.height);
  });

  testWidgets('подписи «Доход» и «Расход» при ×2 не обрезаются «…»',
      (tester) async {
    await pumpTiles(tester, income: 0, expense: 36191556, scale: 2.0);

    for (final label in [
      LanguageManager.l10n.income_title,
      LanguageManager.l10n.expense_title,
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  });
}
