import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/dashboard_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/reload_when_visible.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.changes);

  final ValueNotifier<int> changes;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ReloadWhenVisible {
  int reloads = 0;

  @override
  void initState() {
    super.initState();
    widget.changes.addListener(requestReload);
  }

  @override
  void dispose() {
    widget.changes.removeListener(requestReload);
    super.dispose();
  }

  @override
  void reloadData() => setState(() => reloads++);

  @override
  Widget build(BuildContext context) =>
      Text('reloads: $reloads', textDirection: TextDirection.ltr);
}

/// Вкладка, видимость которой переключается как в `MainShell`.
class _Tab extends StatefulWidget {
  const _Tab(this.changes, this.visible);

  final ValueNotifier<int> changes;
  final ValueNotifier<bool> visible;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: widget.visible,
        builder: (_, visible, __) =>
            TickerMode(enabled: visible, child: _Probe(widget.changes)),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReloadWhenVisible', () {
    late ValueNotifier<int> changes;
    late ValueNotifier<bool> visible;

    setUp(() {
      changes = ValueNotifier(0);
      visible = ValueNotifier(true);
    });

    testWidgets('видимая вкладка перечитывает данные сразу', (tester) async {
      await tester.pumpWidget(_Tab(changes, visible));

      changes.value++;
      await tester.pump();

      expect(find.text('reloads: 1'), findsOneWidget);
    });

    testWidgets(
        'скрытая вкладка копит изменения и перечитывает один раз при показе',
        (tester) async {
      visible.value = false;
      await tester.pumpWidget(_Tab(changes, visible));

      changes.value++;
      changes.value++;
      changes.value++;
      await tester.pump();
      expect(find.text('reloads: 0'), findsOneWidget);

      visible.value = true;
      await tester.pump();
      expect(find.text('reloads: 1'), findsOneWidget);

      // Повторный показ без новых изменений данные не перечитывает
      visible.value = false;
      await tester.pump();
      visible.value = true;
      await tester.pump();
      expect(find.text('reloads: 1'), findsOneWidget);
    });
  });

  group('DashboardScreen: месяц читается один раз', () {
    setUpAll(() async {
      FlutterSecureStorage.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp('perf_db_test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => call.method == 'getApplicationDocumentsDirectory'
            ? tempDir.path
            : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['wifi'],
      );
      EnvironmentConfig.setDefinesForTesting(
          {'API_BASE_URL': 'http://localhost:8000/api/v1'});
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      await LocalDbService.init();
    });

    setUp(() async {
      await LocalDbService.instance.clearAllData();
      await CurrencyFormatter.setCurrency(Currency.usd);
      SelectedPeriodService.instance.reset();
    });

    testWidgets(
        'итог — за весь месяц, страницы по 20 подгружаются из того же списка',
        (tester) async {
      final period = SelectedPeriodService.instance.period;
      for (var i = 0; i < 45; i++) {
        final date = DateTime(period.year, period.month, 1, 0, i);
        LocalDbService.instance.saveTransaction(Transaction(
          amount: 1,
          description: 'op $i',
          dbCategory: Category.food.name,
          dbType: TransactionType.expense.name,
          dateMilliseconds: date.millisecondsSinceEpoch,
          dateCreatedMilliseconds: date.millisecondsSinceEpoch,
          currencyCode: 'USD',
          baseAmount: 1,
        ));
      }

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(),
      ));
      await tester.pump();

      // Итог месяца — по всем 45 операциям, а не по первой странице
      expect(find.textContaining('45'), findsWidgets);
      // Список — от новых к старым: самой старой операции на первой
      // странице нет
      expect(find.text('op 44', skipOffstage: false), findsOneWidget);
      expect(find.text('op 0', skipOffstage: false), findsNothing);

      await tester.scrollUntilVisible(
        find.text('op 0'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('op 0'), findsOneWidget);
      expect(tester.widgetList(find.byType(TransactionItemTile)), isNotEmpty);
    });
  });
}
