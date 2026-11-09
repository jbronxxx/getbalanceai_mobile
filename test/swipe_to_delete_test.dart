import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/swipe_to_delete.dart';

/// Фон экрана в тестах — заметно не похожий ни на карточку, ни на подложку:
/// если между ними щель, в ней будет этот цвет.
const _screen = Color(0xFF0000FF);
const _boundaryKey = Key('swipe_boundary');

Budget _budget() => Budget(
      localId: 1,
      dbCategory: Category.food.name,
      limitAmount: 1000,
      currencyCode: 'USD',
      month: 11,
      year: 2026,
      spent: 0,
      remaining: 1000,
    );

Transaction _transaction() => Transaction(
      localId: 2,
      amount: 10,
      description: '',
      dbCategory: Category.food.name,
      dbType: TransactionType.expense.name,
      dateMilliseconds: DateTime(2026, 11, 5, 12).millisecondsSinceEpoch,
      dateCreatedMilliseconds: 0,
      currencyCode: 'USD',
      baseAmount: 10,
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      backgroundColor: _screen,
      body: RepaintBoundary(
        key: _boundaryKey,
        child: ColoredBox(
          color: _screen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(alignment: Alignment.topCenter, child: child),
          ),
        ),
      ),
    ),
  ));
}

/// Цвет пикселя кадра в глобальных координатах [point].
Future<Color> _pixel(WidgetTester tester, Offset point) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final origin = boundary.localToGlobal(Offset.zero);
  final (image, bytes) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (image, data!);
  }))!;
  final x = (point.dx - origin.dx).round();
  final y = (point.dy - origin.dy).round();
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

/// Начинает свайп влево на [distance] и не отпускает палец.
Future<TestGesture> _startSwipe(
  WidgetTester tester,
  Finder target,
  double distance,
) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.moveBy(const Offset(-20, 0));
  await gesture.moveBy(Offset(-distance, 0));
  await tester.pump();
  return gesture;
}

void _expectNoGap(Color pixel, String where) {
  expect(
    pixel,
    isNot(_screen),
    reason: '$where: между сдвинутой записью и подложкой виден фон экрана',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await CurrencyFormatter.setCurrency(Currency.usd);
  });

  testWidgets('карточка лимита: у угла при свайпе нет щели до подложки',
      (tester) async {
    await _pump(
      tester,
      BudgetItemCard(
        budget: _budget(),
        currentSpent: 250,
        isFirst: false,
        showSwipeHint: false,
        onTap: () {},
        onDelete: () {},
        onHintShown: () {},
      ),
    );
    final card = find.byType(BudgetItemCard);
    final frame = tester.getRect(card);
    final gesture = await _startSwipe(tester, card, 120);

    // Правый край сдвинутой карточки — граница с подложкой
    final moving = find.descendant(
      of: find.byType(Dismissible),
      matching: find.byType(Material),
    );
    final edge = tester.getRect(moving.first).right;
    expect(edge, lessThan(frame.right - 100), reason: 'свайп не начался');

    // Угол сдвинутой карточки и подложка рядом с ним — не фон экрана
    final top = frame.top + 3;
    _expectNoGap(await _pixel(tester, Offset(edge - 3, top)), 'угол карточки');
    _expectNoGap(await _pixel(tester, Offset(edge + 3, top)), 'край подложки');
    final bottom = frame.bottom - 16 - 3; // 16 — нижний отступ карточки
    _expectNoGap(await _pixel(tester, Offset(edge - 3, bottom)), 'нижний угол');

    // Скругление общее: за внешним углом рамки — фон экрана
    expect(
      await _pixel(tester, Offset(frame.right - 1, frame.top + 1)),
      _screen,
    );
    await gesture.up();
  });

  testWidgets('строка операции в карточке дня: при свайпе нет щели',
      (tester) async {
    await _pump(
      tester,
      DayGroupWidget(
        date: DateTime(2026, 11, 5),
        transactions: [_transaction()],
        onTransactionTap: (_) {},
        onTransactionDelete: (_) {},
      ),
    );
    final tile = find.byType(TransactionItemTile);
    final row = tester.getRect(tile);
    final gesture = await _startSwipe(tester, tile, 120);

    final moving = find.descendant(
      of: find.byType(Dismissible),
      matching: find.byType(Material),
    );
    final edge = tester.getRect(moving.first).right;
    expect(edge, lessThan(row.right - 100), reason: 'свайп не начался');
    _expectNoGap(
      await _pixel(tester, Offset(edge - 3, row.top + 3)),
      'угол строки',
    );
    _expectNoGap(
      await _pixel(tester, Offset(edge + 3, row.top + 3)),
      'край подложки',
    );
    await gesture.up();
  });

  testWidgets('операции и лимиты удаляются свайпом через общий SwipeToDelete',
      (tester) async {
    await _pump(
      tester,
      Column(children: [
        BudgetItemCard(
          budget: _budget(),
          currentSpent: 0,
          isFirst: false,
          showSwipeHint: false,
          onTap: () {},
          onDelete: () {},
          onHintShown: () {},
        ),
        TransactionItemTile(
          transaction: _transaction(),
          onTap: () {},
          onDelete: () {},
        ),
      ]),
    );
    expect(find.byType(SwipeToDelete), findsNWidgets(2));
    expect(find.byType(Dismissible), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.byType(Dismissible),
        matching: find.byType(SwipeToDelete),
      ),
      findsNWidgets(2),
    );
  });
}
