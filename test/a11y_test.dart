import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/service_unavailable_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/app_alerts.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/widgets/user_avatar.dart';

/// Доступность (блок `fix/a11y`): удаление лимита без свайпа, прокрутка
/// при крупном шрифте, зоны нажатия и подписи для TalkBack.

class _MockLocalDbService extends Mock implements LocalDbService {}

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: home,
    );

Budget _budget() => Budget(
      localId: 7,
      dbCategory: Category.food.name,
      limitAmount: 100,
      currencyCode: 'USD',
      month: 11,
      year: 2026,
      spent: 0,
      remaining: 100,
    );

/// Маленький экран телефона.
void _smallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
    registerFallbackValue(TransactionType.expense);
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await CurrencyFormatter.setCurrency(Currency.usd);
    final db = _MockLocalDbService();
    when(() => db.getFrequentCategories(any())).thenReturn(const []);
    LocalDbService.instance = db;
    addTearDown(() => LocalDbService.instance = null);
  });

  group('A11Y-01: кнопка «Удалить» в шторке лимита', () {
    /// Открывает шторку поверх экрана с текстом `screen`.
    Future<void> openSheet(WidgetTester tester, AddBudgetSheet sheet) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => sheet,
              ),
              child: const Text('screen'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('screen'));
      await tester.pumpAndSettle();
    }

    final deleteButton = find.byKey(const ValueKey('budget_sheet_delete'));

    testWidgets('при правке: закрывает шторку и вызывает onDelete',
        (tester) async {
      var deleted = 0;
      var saved = 0;
      await openSheet(
        tester,
        AddBudgetSheet(
          selectedMonth: 11,
          selectedYear: 2026,
          budgetToEdit: _budget(),
          onSaved: () => saved++,
          onDelete: () => deleted++,
        ),
      );

      expect(deleteButton, findsOneWidget);
      expect(
        find.descendant(
          of: deleteButton,
          matching: find.text(LanguageManager.l10n.delete_btn),
        ),
        findsOneWidget,
      );

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(deleted, 1);
      expect(saved, 0);
      expect(find.byType(AddBudgetSheet), findsNothing);
      expect(find.text('screen'), findsOneWidget);
    });

    testWidgets('при создании лимита кнопки нет', (tester) async {
      await openSheet(
        tester,
        AddBudgetSheet(
          selectedMonth: 11,
          selectedYear: 2026,
          onSaved: () {},
          onDelete: () {},
        ),
      );

      expect(deleteButton, findsNothing);
      expect(find.text(LanguageManager.l10n.save_btn), findsOneWidget);
    });

    testWidgets('без onDelete кнопки нет', (tester) async {
      await openSheet(
        tester,
        AddBudgetSheet(
          selectedMonth: 11,
          selectedYear: 2026,
          budgetToEdit: _budget(),
          onSaved: () {},
        ),
      );

      expect(deleteButton, findsNothing);
    });
  });

  group('A11Y-02: крупный системный шрифт', () {
    testWidgets(
        'диалог подтверждения прокручивается, кнопка подтверждения '
        'достижима', (tester) async {
      _smallPhone(tester);
      bool? result;
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AppAlerts.showConfirmDialog(
                  context,
                  title: LanguageManager.l10n.delete_account_title,
                  message: LanguageManager.l10n.delete_account_confirm,
                  confirmText: LanguageManager.l10n.delete_account_confirm_btn,
                  isDestructive: true,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
        textScale: 3,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dialogScroll = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      );
      expect(dialogScroll, findsOneWidget);
      expect(
        tester.state<ScrollableState>(dialogScroll).position.maxScrollExtent,
        greaterThan(0),
        reason: 'при шрифте ×3 диалог не помещается на экран 360×640',
      );

      final confirm =
          find.text(LanguageManager.l10n.delete_account_confirm_btn);
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('диалог «Сервис недоступен» при крупном шрифте без обрезки',
        (tester) async {
      _smallPhone(tester);
      var retried = 0;
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppAlerts.showServiceUnavailableDialog(
                context,
                onRetry: () => retried++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        textScale: 3,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final retry = find.text(LanguageManager.l10n.service_unavailable_retry);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(retried, 1);
    });

    testWidgets('экран «Сервис недоступен» прокручивается до «Повторить»',
        (tester) async {
      _smallPhone(tester);
      var retried = 0;
      await tester.pumpWidget(_app(
        ServiceUnavailableScreen(onRetry: () => retried++),
        textScale: 3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        greaterThan(0),
      );

      final retry = find.text(LanguageManager.l10n.service_unavailable_retry);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);

      expect(retried, 1);
    });

    testWidgets('при обычном шрифте экран по центру и без прокрутки',
        (tester) async {
      _smallPhone(tester);
      await tester.pumpWidget(_app(ServiceUnavailableScreen(onRetry: () {})));
      await tester.pumpAndSettle();

      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        0,
      );
      final title = find.text(LanguageManager.l10n.service_unavailable_title);
      final screenCenter = tester.getCenter(find.byType(Scaffold)).dy;
      final top = tester.getTopLeft(find.byIcon(Icons.engineering_rounded)).dy;
      final bottom = tester
          .getBottomLeft(
              find.text(LanguageManager.l10n.service_unavailable_retry))
          .dy;
      expect(title, findsOneWidget);
      expect(top, lessThan(screenCenter));
      expect(bottom, greaterThan(screenCenter));
    });
  });

  group('A11Y-03: зоны нажатия', () {
    testWidgets('значок валюты нажимается в полосе 48 dp, сам не меняется',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: TextField(
              decoration: InputDecoration(
                suffixIcon: CurrencyBadge(
                  currency: Currency.usd,
                  onTap: () => taps++,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
      )));

      final area = find.byKey(const ValueKey('currency_badge_tap_area'));
      final badge = find.byType(InkWell);
      expect(tester.getSize(area).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(tester.getSize(badge).height, lessThan(kMinInteractiveDimension));

      // Над бейджем, но в пределах полосы
      final badgeRect = tester.getRect(badge);
      final areaRect = tester.getRect(area);
      await tester.tapAt(Offset(badgeRect.center.dx, areaRect.top + 2));
      await tester.pump();
      expect(taps, 1);

      // По самому бейджу — одно нажатие, не два
      await tester.tap(badge);
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('значок валюты без onTap — не кнопка', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: Center(child: CurrencyBadge(currency: Currency.usd)),
      )));

      expect(
          find.byKey(const ValueKey('currency_badge_tap_area')), findsNothing);
      expect(
        tester.getSemantics(find.text('USD')),
        isNot(matchesSemantics(isButton: true)),
      );
    });

    testWidgets('аватар в шапке: зона 48 dp, подпись «Профиль», круг на месте',
        (tester) async {
      await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
      addTearDown(() => ApiService.instance.auth.setTokens(null, null));
      var opened = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(
          actions: [
            DashboardAccountAction(
              onLogin: () {},
              onOpenProfile: () => opened++,
            ),
          ],
        ),
      )));
      await tester.pump();

      final area = find.byKey(const ValueKey('dashboard_profile_avatar'));
      expect(tester.getSize(area), const Size.square(kMinInteractiveDimension));
      final screenRight = tester.getSize(find.byType(Scaffold)).width;
      final avatarRight = tester.getTopRight(find.byType(UserAvatar)).dx;
      expect(screenRight - avatarRight, 16,
          reason: 'круг аватара по-прежнему в 16 dp от края экрана');

      expect(
        tester.getSemantics(area),
        matchesSemantics(
          label: LanguageManager.l10n.profile,
          isButton: true,
          hasTapAction: true,
        ),
      );

      await tester.tapAt(tester.getTopLeft(area) + const Offset(2, 2));
      expect(opened, 1);
      handle.dispose();
    });
  });

  group('A11Y-03: подписи для TalkBack', () {
    testWidgets('«Расход/Доход» — кнопки с отметкой выбранного',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(Scaffold(
        body: TransactionTypeToggle(
          type: TransactionType.expense,
          onChanged: (_) {},
        ),
      )));

      expect(
        tester.getSemantics(find.text(LanguageManager.l10n.expense_title)),
        matchesSemantics(
          label: LanguageManager.l10n.expense_title,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text(LanguageManager.l10n.income_title)),
        matchesSemantics(
          label: LanguageManager.l10n.income_title,
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('группа категории озвучивает, что откроет или скроет нажатие',
        (tester) async {
      final handle = tester.ensureSemantics();
      final date = DateTime(2026, 10, 15);
      final summary = CategoryMonthSummary.fromTransactions([
        Transaction(
          localId: 1,
          amount: 30,
          description: 'Обед',
          dbCategory: Category.food.name,
          dbType: TransactionType.expense.name,
          dateMilliseconds: date.millisecondsSinceEpoch,
          dateCreatedMilliseconds: date.millisecondsSinceEpoch,
          currencyCode: 'USD',
          baseAmount: 30,
        ),
      ]).single;
      await tester.pumpWidget(_app(Scaffold(
        body: CategoryMonthGroup(
          summary: summary,
          onTransactionTap: (_) {},
          onTransactionDelete: (_) {},
        ),
      )));

      final header = find.byKey(const ValueKey('category_group_food_expense'));
      SemanticsNode node() => tester.getSemantics(header);

      expect(node().label, contains('Питание'));
      expect(
        node(),
        matchesSemantics(
          label: node().label,
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          onTapHint: LanguageManager.l10n.category_group_expand_hint,
        ),
      );

      await tester.tap(header);
      await tester.pumpAndSettle();

      expect(
        node(),
        matchesSemantics(
          label: node().label,
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          onTapHint: LanguageManager.l10n.category_group_collapse_hint,
        ),
      );
      expect(node().label, isNot(contains('Обед')),
          reason: 'строки операций — отдельные узлы, не часть заголовка');
      handle.dispose();
    });
  });
}
