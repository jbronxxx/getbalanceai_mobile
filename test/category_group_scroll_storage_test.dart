import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp('cat_storage_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    CurrencyFormatter.setCurrency(Currency.rub);
  });

  Transaction createSampleTx(int id, Category category, double amount) {
    return Transaction(
      localId: id,
      amount: amount,
      description: 'Тестовая транзакция $id',
      dbCategory: category.name,
      dbType: TransactionType.expense.name,
      dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      currencyCode: 'RUB',
      exchangeRate: 1.0,
      baseAmount: amount,
    );
  }

  testWidgets(
      'CategoryGroupWidget не падает при наличии сохраненного double в PageStorage предка',
      (WidgetTester tester) async {
    final bucket = PageStorageBucket();
    const ancestorKey = PageStorageKey('dashboard_tab');
    final tx = createSampleTx(1, Category.food, 350.0);
    final date = DateTime(2026, 10, 12);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: PageStorage(
          bucket: bucket,
          child: Scaffold(
            body: Container(
              key: ancestorKey,
              child: Builder(
                builder: (context) {
                  // Симулируем ситуацию, когда ScrollPosition сохранил double в PageStorage
                  PageStorage.of(context).writeState(context, 150.5);
                  return CategoryGroupWidget(
                    date: date,
                    category: Category.food,
                    transactions: [tx],
                    onTransactionTap: (_) {},
                    onTransactionDelete: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Виджет успешно смонтирован без ошибки type cast (локализация Category.food - «Питание»)
    expect(find.text('Питание'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsOneWidget);

    // Раскрытие ExpansionTile работает стабильно
    await tester.tap(find.text('Питание'));
    await tester.pumpAndSettle();
    expect(find.text('Тестовая транзакция 1'), findsOneWidget);
  });

  testWidgets(
      'Скролл списка с DayGroupWidget и CategoryGroupWidget не вызывает ошибку приведения double к bool',
      (WidgetTester tester) async {
    final bucket = PageStorageBucket();
    final date1 = DateTime(2026, 10, 12);
    final date2 = DateTime(2026, 10, 11);

    final group1 = {
      Category.food: [createSampleTx(1, Category.food, 200.0)],
      Category.transport: [createSampleTx(2, Category.transport, 60.0)],
    };
    final group2 = {
      Category.shopping: [createSampleTx(3, Category.shopping, 1500.0)],
      Category.entertainment: [
        createSampleTx(4, Category.entertainment, 700.0)
      ],
    };

    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: PageStorage(
          bucket: bucket,
          child: Scaffold(
            body: Container(
              key: const PageStorageKey('dashboard_tab'),
              child: CustomScrollView(
                key: const PageStorageKey('dashboard_custom_scroll_view'),
                controller: scrollController,
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      DayGroupWidget(
                        date: date1,
                        categories: group1,
                        onTransactionTap: (_) {},
                        onTransactionDelete: (_) {},
                      ),
                      const SizedBox(height: 300),
                      DayGroupWidget(
                        date: date2,
                        categories: group2,
                        onTransactionTap: (_) {},
                        onTransactionDelete: (_) {},
                      ),
                      const SizedBox(height: 500),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Проверяем начальное состояние
    expect(find.text('Питание'), findsOneWidget);

    // Скроллим вниз с помощью scrollController: позиция смещается (double),
    // ScrollPosition записывает смещение в PageStorage
    scrollController.jumpTo(250.0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Скроллим обратно наверх: проверяем, что виджеты восстанавливаются без ошибок типизации
    scrollController.jumpTo(0.0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Питание'), findsOneWidget);
  });
}
