import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/report_export/report_export_cubit.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/insights/report_export_action.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

class _MockExportService extends Mock implements ReportExportService {}

class _MockEntitlements extends Mock implements EntitlementService {}

class _FakeL10n extends Fake implements AppLocalizations {}

Transaction _tx({
  required DateTime date,
  double amount = 100,
  String category = 'food',
  String type = 'expense',
  String description = 'Кофе',
  String currencyCode = 'USD',
}) {
  return Transaction(
    amount: amount,
    description: description,
    dbCategory: category,
    dbType: type,
    dateMilliseconds: date.millisecondsSinceEpoch,
    dateCreatedMilliseconds: date.millisecondsSinceEpoch,
    currencyCode: currencyCode,
    baseAmount: amount,
  );
}

Budget _budget(String category, double limit, int month, int year) {
  return Budget(
    dbCategory: category,
    limitAmount: limit,
    month: month,
    year: year,
    spent: 0,
    remaining: limit,
  );
}

ReportData _sampleData({String description = 'Кофе'}) {
  return ReportDataService.assemble(
    period: ReportPeriod.month(3, 2030),
    currency: Currency.usd,
    transactions: [
      _tx(
          date: DateTime(2030, 3, 5, 9, 30),
          amount: 12.5,
          description: description),
      _tx(
        date: DateTime(2030, 3, 1),
        amount: 1000,
        category: 'salary',
        type: 'income',
        description: 'Аванс',
      ),
    ],
    budgets: [_budget('food', 50, 3, 2030)],
    exchange: CurrencyExchangeService.instance,
    now: DateTime(2030, 4, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(ReportPeriod.month(1, 2030));
    registerFallbackValue(ReportFormat.pdf);
    registerFallbackValue(ReportDeliveryMode.share);
    registerFallbackValue(_FakeL10n());
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
  });

  group('ReportPeriod', () {
    test('месяц включает последний день, високосный февраль — 29 дней', () {
      final period = ReportPeriod.month(2, 2024);

      expect(period.start, DateTime(2024, 2, 1));
      expect(period.end, DateTime(2024, 2, 29));
      expect(period.endExclusiveMilliseconds,
          DateTime(2024, 3, 1).millisecondsSinceEpoch);
    });

    test('время в границах отбрасывается', () {
      final period =
          ReportPeriod(DateTime(2030, 1, 5, 18, 40), DateTime(2030, 1, 6, 3));

      expect(period.start, DateTime(2030, 1, 5));
      expect(period.end, DateTime(2030, 1, 6));
    });

    test('fullMonths возвращает только полностью покрытые месяцы', () {
      final period = ReportPeriod(DateTime(2030, 1, 15), DateTime(2030, 3, 31));

      expect(period.fullMonths, [
        (month: 2, year: 2030),
        (month: 3, year: 2030),
      ]);
    });

    test('год содержит 12 полных месяцев', () {
      expect(ReportPeriod.year(2030).fullMonths, hasLength(12));
    });
  });

  group('ReportDataService.assemble', () {
    test('считает итоги, категории и выполнение лимитов', () {
      final data = ReportDataService.assemble(
        period: ReportPeriod.month(3, 2030),
        currency: Currency.usd,
        transactions: [
          _tx(date: DateTime(2030, 3, 2), amount: 30),
          _tx(date: DateTime(2030, 3, 3), amount: 40, category: 'transport'),
          _tx(date: DateTime(2030, 3, 4), amount: 60),
          _tx(
            date: DateTime(2030, 3, 1),
            amount: 500,
            category: 'salary',
            type: 'income',
          ),
        ],
        budgets: [_budget('food', 80, 3, 2030)],
        exchange: CurrencyExchangeService.instance,
        now: DateTime(2030, 4, 1),
      );

      expect(data.totalIncome, 500);
      expect(data.totalExpense, 130);
      expect(data.balance, 370);
      expect(data.categoryExpenses.first.key, Category.food);
      expect(data.categoryExpenses.first.value, 90);
      expect(data.budgetLines.single.spent, 90);
      expect(data.budgetLines.single.isExceeded, isTrue);
    });

    test('сумма в другой валюте конвертируется в базовую', () {
      final exchange = CurrencyExchangeService.instance;
      final data = ReportDataService.assemble(
        period: ReportPeriod.month(3, 2030),
        currency: Currency.usd,
        transactions: [
          _tx(
            date: DateTime(2030, 3, 2),
            amount: 100000,
            currencyCode: 'UZS',
          ),
        ],
        budgets: const [],
        exchange: exchange,
        now: DateTime(2030, 4, 1),
      );

      final row = data.transactions.single;
      expect(row.amount, 100000);
      expect(row.currency, Currency.uzs);
      expect(row.baseAmount,
          exchange.convert(100000, from: Currency.uzs, to: Currency.usd));
    });

    test('лимит в другой валюте переводится в валюту отчёта', () {
      final exchange = CurrencyExchangeService.instance;
      final eurBudget = _budget('food', 100, 3, 2030)..currencyCode = 'EUR';
      final data = ReportDataService.assemble(
        period: ReportPeriod.month(3, 2030),
        currency: Currency.usd,
        transactions: const [],
        budgets: [eurBudget],
        exchange: exchange,
        now: DateTime(2030, 4, 1),
      );

      expect(
        data.budgetLines.single.limit,
        exchange.convert(100, from: Currency.eur, to: Currency.usd),
      );
    });
  });

  group('ReportData.balance', () {
    test('итог периода отрицателен, если есть только расходы', () {
      final data = ReportDataService.assemble(
        period: ReportPeriod.month(3, 2030),
        currency: Currency.usd,
        transactions: [_tx(date: DateTime(2030, 3, 2), amount: 40)],
        budgets: const [],
        exchange: CurrencyExchangeService.instance,
        now: DateTime(2030, 4, 1),
      );

      expect(data.totalIncome, 0);
      expect(data.balance, -40);
      expect(
        CurrencyFormatter.format(data.balance,
            showSymbol: false, showSign: true, currency: Currency.usd),
        '-40,00',
      );
    });
  });

  group('CsvReportGenerator', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('русский диалект: BOM, разделитель «;», десятичная запятая', () {
      final csv =
          CsvReportGenerator.generate(_sampleData(), ru, languageCode: 'ru');
      final lines = csv.split('\r\n');

      expect(csv.startsWith('﻿'), isTrue);
      expect(
          lines.first, '﻿Дата;Тип;Категория;Описание;Сумма;Валюта;Сумма в USD');
      expect(lines[1], '2030-03-05 09:30;Расход;Питание;Кофе;12,50;USD;12,50');
      expect(lines.last, isEmpty);
    });

    test('английский диалект: разделитель «,» и точка', () {
      final csv =
          CsvReportGenerator.generate(_sampleData(), en, languageCode: 'en');

      expect(csv.split('\r\n')[1], contains('12.50,USD,12.50'));
    });

    test('экранирует кавычки, разделитель и переносы строк', () {
      final csv = CsvReportGenerator.generate(
        _sampleData(description: 'Кофе; "эспрессо"\nдва'),
        ru,
        languageCode: 'ru',
      );

      expect(csv, contains('"Кофе; ""эспрессо""\nдва"'));
    });

    test('нейтрализует формулы в описании', () {
      final csv = CsvReportGenerator.generate(
        _sampleData(description: '=HYPERLINK("http://x")'),
        ru,
        languageCode: 'ru',
      );

      expect(csv, contains('\'=HYPERLINK'));
      expect(csv, isNot(contains(';=HYPERLINK')));
    });
  });

  group('PdfReportGenerator', () {
    final ru = lookupAppLocalizations(const Locale('ru'));

    Future<pw.Font> font(String name) async {
      final bytes = await File('assets/google_fonts/$name').readAsBytes();
      return pw.Font.ttf(ByteData.sublistView(bytes));
    }

    test('создаёт валидный PDF с кириллицей', () async {
      final bytes = await PdfReportGenerator.generate(
        _sampleData(),
        ru,
        languageCode: 'ru',
        regularFont: await font('Inter-Regular.ttf'),
        boldFont: await font('Inter-Bold.ttf'),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('большая выгрузка (больше 20 страниц) не падает', () async {
      final transactions = [
        for (var i = 0; i < 1500; i++)
          _tx(date: DateTime(2030, 3, 1 + i % 28), amount: 10.0 + i),
      ];
      final data = ReportDataService.assemble(
        period: ReportPeriod.month(3, 2030),
        currency: Currency.usd,
        transactions: transactions,
        budgets: const [],
        exchange: CurrencyExchangeService.instance,
        now: DateTime(2030, 4, 1),
      );

      final bytes = await PdfReportGenerator.generate(
        data,
        ru,
        languageCode: 'ru',
        regularFont: await font('Inter-Regular.ttf'),
        boldFont: await font('Inter-Bold.ttf'),
      );

      expect(bytes.length, greaterThan(10000));
    });
  });

  group('ReportExportCubit', () {
    late _MockExportService exporter;
    late _MockEntitlements entitlements;
    final l10n = lookupAppLocalizations(const Locale('ru'));

    setUp(() {
      exporter = _MockExportService();
      entitlements = _MockEntitlements();
      when(() => entitlements.isEnabled(AppFeature.reportExport))
          .thenReturn(true);
    });

    ReportExportCubit build() => ReportExportCubit(
          month: 3,
          year: 2030,
          exportService: exporter,
          entitlements: entitlements,
        );

    void stubExport(Future<ReportExportOutcome> Function() answer) {
      when(() => exporter.export(
            period: any(named: 'period'),
            format: any(named: 'format'),
            mode: any(named: 'mode'),
            l10n: any(named: 'l10n'),
            languageCode: any(named: 'languageCode'),
            sharePositionOrigin: any(named: 'sharePositionOrigin'),
          )).thenAnswer((_) => answer());
    }

    blocTest<ReportExportCubit, ReportExportState>(
      'успешная выгрузка: exporting -> success',
      setUp: () => stubExport(() async => ReportExportOutcome.completed),
      build: build,
      act: (c) => c.export(
          mode: ReportDeliveryMode.share, l10n: l10n, languageCode: 'ru'),
      expect: () => [
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.exporting),
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.success),
      ],
      verify: (_) {
        final captured = verify(() => exporter.export(
              period: captureAny(named: 'period'),
              format: ReportFormat.pdf,
              mode: ReportDeliveryMode.share,
              l10n: l10n,
              languageCode: 'ru',
              sharePositionOrigin: null,
            )).captured.single as ReportPeriod;
        expect(captured.start, DateTime(2030, 3, 1));
        expect(captured.end, DateTime(2030, 3, 31));
      },
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'нет операций за период: exporting -> empty',
      setUp: () => stubExport(() async => ReportExportOutcome.empty),
      build: build,
      act: (c) => c.export(
          mode: ReportDeliveryMode.share, l10n: l10n, languageCode: 'ru'),
      expect: () => [
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.exporting),
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.empty),
      ],
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'сохранение: режим попадает в сервис и в состояние',
      setUp: () => stubExport(() async => ReportExportOutcome.completed),
      build: build,
      act: (c) => c.export(
          mode: ReportDeliveryMode.save, l10n: l10n, languageCode: 'ru'),
      verify: (c) {
        expect(c.state.mode, ReportDeliveryMode.save);
        expect(c.state.status, ReportExportStatus.success);
        verify(() => exporter.export(
              period: any(named: 'period'),
              format: any(named: 'format'),
              mode: ReportDeliveryMode.save,
              l10n: any(named: 'l10n'),
              languageCode: any(named: 'languageCode'),
              sharePositionOrigin: any(named: 'sharePositionOrigin'),
            )).called(1);
      },
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'отмена выбора места сохранения: возврат в idle без ошибки',
      setUp: () => stubExport(() async => ReportExportOutcome.cancelled),
      build: build,
      act: (c) => c.export(
          mode: ReportDeliveryMode.save, l10n: l10n, languageCode: 'ru'),
      expect: () => [
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.exporting),
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.idle),
      ],
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'ошибка формирования: exporting -> failure',
      setUp: () => stubExport(() async => throw const FileSystemException()),
      build: build,
      act: (c) => c.export(
          mode: ReportDeliveryMode.share, l10n: l10n, languageCode: 'ru'),
      expect: () => [
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.exporting),
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.failure),
      ],
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'функция закрыта тарифом: locked, сервис не вызывается',
      setUp: () => when(() => entitlements.isEnabled(AppFeature.reportExport))
          .thenReturn(false),
      build: build,
      act: (c) => c.export(
          mode: ReportDeliveryMode.share, l10n: l10n, languageCode: 'ru'),
      expect: () => [
        isA<ReportExportState>()
            .having((s) => s.status, 'status', ReportExportStatus.locked),
      ],
      verify: (_) => verifyNever(() => exporter.export(
            period: any(named: 'period'),
            format: any(named: 'format'),
            mode: any(named: 'mode'),
            l10n: any(named: 'l10n'),
            languageCode: any(named: 'languageCode'),
            sharePositionOrigin: any(named: 'sharePositionOrigin'),
          )),
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'свой диапазон не выбран: выгрузка не запускается',
      build: build,
      act: (c) {
        c.selectPreset(ReportPeriodPreset.custom);
        return c.export(
            mode: ReportDeliveryMode.share, l10n: l10n, languageCode: 'ru');
      },
      expect: () => [
        isA<ReportExportState>().having((s) => s.canExport, 'canExport', false),
      ],
      verify: (_) => verifyNever(() => exporter.export(
            period: any(named: 'period'),
            format: any(named: 'format'),
            mode: any(named: 'mode'),
            l10n: any(named: 'l10n'),
            languageCode: any(named: 'languageCode'),
            sharePositionOrigin: any(named: 'sharePositionOrigin'),
          )),
    );

    blocTest<ReportExportCubit, ReportExportState>(
      'свой диапазон и формат попадают в состояние',
      build: build,
      act: (c) {
        c.selectFormat(ReportFormat.csv);
        c.setCustomPeriod(DateTime(2030, 1, 10), DateTime(2030, 2, 5));
      },
      verify: (c) {
        expect(c.state.format, ReportFormat.csv);
        expect(c.state.preset, ReportPeriodPreset.custom);
        expect(c.state.period?.start, DateTime(2030, 1, 10));
        expect(c.state.period?.end, DateTime(2030, 2, 5));
      },
    );
  });

  group('LocalDbService.getTransactionsInRange', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('report_range_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => call.method == 'getApplicationDocumentsDirectory'
            ? tempDir.path
            : null,
      );
      await LocalDbService.init();
    });

    test('границы периода включительно, внутри — от новых к старым', () {
      final db = LocalDbService.instance;
      db.addTransaction(_tx(date: DateTime(2031, 5, 31, 23, 59), amount: 1));
      db.addTransaction(_tx(date: DateTime(2031, 6, 1), amount: 2));
      db.addTransaction(_tx(date: DateTime(2031, 6, 10, 12), amount: 3));
      db.addTransaction(_tx(date: DateTime(2031, 6, 30, 23, 59), amount: 4));
      db.addTransaction(_tx(date: DateTime(2031, 7, 1), amount: 5));

      final result = db.getTransactionsInRange(ReportPeriod.month(6, 2031));

      expect(result.map((t) => t.amount), [4, 3, 2]);
    });
  });

  group('ReportExportAction', () {
    testWidgets('открывает форму выгрузки с выбором периода и формата',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ReportExportAction(selectedMonth: 3, selectedYear: 2030),
          ),
        ),
      );

      expect(find.byTooltip('Выгрузка отчёта'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Март 2030'), findsOneWidget);
      expect(find.text('Год 2030'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
      // Одна широкая кнопка «Скачать отчёт» и компактная иконка «Поделиться»
      expect(find.text('Скачать отчёт'), findsOneWidget);
      expect(find.text('Сохранить'), findsNothing);
      expect(find.text('Поделиться'), findsNothing);
      expect(find.byTooltip('Поделиться'), findsOneWidget);
      final download = tester.getSize(
        find.byKey(const ValueKey('report_download_button')),
      );
      final share =
          tester.getSize(find.byKey(const ValueKey('report_share_button')));
      expect(download.width, greaterThan(share.width * 3));

      await tester.tap(find.text('CSV'));
      await tester.pump();
      final segmented = tester.widget<SegmentedButton<ReportFormat>>(
        find.byType(SegmentedButton<ReportFormat>),
      );
      expect(segmented.selected, {ReportFormat.csv});
    });
  });
}
