import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/insights/insights_cubit.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/insights_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/period/period.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockConnectivity extends Mock implements Connectivity {}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = SelectedPeriodService.instance;

  setUpAll(() {
    LanguageManager.initFallback();
    registerFallbackValue(CancelToken());
  });

  setUp(service.reset);
  tearDown(service.reset);

  group('MonthPeriod', () {
    test('переходит через границу года', () {
      expect(const MonthPeriod(2026, 1).previous, const MonthPeriod(2025, 12));
      expect(const MonthPeriod(2025, 12).next, const MonthPeriod(2026, 1));
      expect(const MonthPeriod(2026, 5).next, const MonthPeriod(2026, 6));
    });

    test('сравнивает периоды', () {
      expect(const MonthPeriod(2025, 12).isBefore(const MonthPeriod(2026, 1)),
          isTrue);
      expect(const MonthPeriod(2026, 2).isAfter(const MonthPeriod(2026, 1)),
          isTrue);
      expect(const MonthPeriod(2026, 1), const MonthPeriod(2026, 1));
    });
  });

  group('SelectedPeriodService', () {
    test('по умолчанию выбран текущий месяц', () {
      expect(service.period, MonthPeriod.current());
    });

    test('листает месяцы и уведомляет подписчиков', () {
      final start = service.period;
      var notified = 0;
      void listener() => notified++;
      service.periodNotifier.addListener(listener);
      addTearDown(() => service.periodNotifier.removeListener(listener));

      service.previous();
      expect(service.period, start.previous);
      service.next();
      expect(service.period, start);
      expect(notified, 2);
    });

    test('игнорирует период вне диапазона и не уходит за границы', () {
      final start = service.period;
      service.select(MonthPeriod(
          DateTime.now().year - SelectedPeriodService.yearRange - 1, 6));
      expect(service.period, start);

      service.select(service.earliest);
      expect(service.canGoBack, isFalse);
      service.previous();
      expect(service.period, service.earliest);

      service.select(service.latest);
      expect(service.canGoForward, isFalse);
      service.next();
      expect(service.period, service.latest);
    });
  });

  group('PeriodSwitcher', () {
    test('подпись без года для текущего года и с годом для других', () {
      final now = DateTime(2026, 10, 15);
      expect(
        PeriodSwitcher.label(const MonthPeriod(2026, 10), now),
        LanguageManager.getMonthName(10),
      );
      expect(
        PeriodSwitcher.label(const MonthPeriod(2025, 10), now),
        '${LanguageManager.getMonthName(10)} 2025',
      );
    });

    testWidgets('стрелки меняют общий период и подпись', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PeriodSwitcher()));
      final start = service.period;

      await tester.tap(find.byKey(const ValueKey('period_next')));
      await tester.pump();

      expect(service.period, start.next);
      expect(find.text(PeriodSwitcher.label(start.next)), findsOneWidget);
    });

    testWidgets('лист выбора позволяет выбрать месяц прошлого года',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const PeriodSwitcher()));
      final lastYear = service.period.year - 1;

      await tester.tap(find.byKey(const ValueKey('period_label')));
      await tester.pumpAndSettle();
      expect(find.byType(PeriodPickerSheet), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('period_sheet_previous_year')));
      await tester.pump();
      expect(find.text('$lastYear'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('period_sheet_month_3')));
      await tester.pumpAndSettle();

      expect(service.period, MonthPeriod(lastYear, 3));
      expect(find.byType(PeriodPickerSheet), findsNothing);
      expect(
        find.text(PeriodSwitcher.label(MonthPeriod(lastYear, 3))),
        findsOneWidget,
      );
    });
  });

  group('LiquidGlassNavBar с центральной кнопкой', () {
    testWidgets('кнопка вызывает действие, индексы вкладок не сдвигаются',
        (tester) async {
      var pressed = false;
      int? selected;

      await tester.pumpWidget(_buildTestApp(
        Align(
          alignment: Alignment.bottomCenter,
          child: LiquidGlassNavBar(
            selectedIndex: 0,
            onDestinationSelected: (i) => selected = i,
            centerAction: LiquidGlassNavAction(
              tooltip: 'Новая запись',
              onPressed: () => pressed = true,
            ),
            destinations: const [
              LiquidGlassNavItem(icon: Icons.wallet_rounded, label: 'A'),
              LiquidGlassNavItem(icon: Icons.donut_small_rounded, label: 'B'),
              LiquidGlassNavItem(icon: Icons.auto_awesome_rounded, label: 'C'),
              LiquidGlassNavItem(icon: Icons.person_rounded, label: 'D'),
            ],
          ),
        ),
      ));

      final button = find.byKey(const ValueKey('nav_center_action'));
      expect(button, findsOneWidget);

      // Кнопка стоит между второй и третьей вкладкой и выше островка.
      final buttonCenter = tester.getCenter(button);
      expect(buttonCenter.dx, greaterThan(tester.getCenter(find.text('B')).dx));
      expect(buttonCenter.dx, lessThan(tester.getCenter(find.text('C')).dx));
      expect(
        tester.getTopLeft(button).dy,
        lessThan(tester.getTopLeft(find.text('B')).dy),
      );

      await tester.tap(button);
      expect(pressed, isTrue);

      await tester.tap(find.text('C'));
      expect(selected, 2);
    });
  });

  group('InsightsScreen и общий период', () {
    late _MockApiService api;
    late _MockConnectivity connectivity;
    late StreamController<bool> authController;

    /// Бэкенд: generate=false — отчёта нет, generate=true — готовый отчёт.
    void stubBackend() {
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        final generate = invocation.namedArguments[#generate] as bool;
        return generate
            ? {
                'insights': ['Сгенерированный отчёт'],
                'state': 'ready'
              }
            : {'insights': <String>[], 'state': 'not_generated'};
      });
    }

    List<bool> generateFlags() => verify(() => api.getInsights(
          currency: any(named: 'currency'),
          locale: any(named: 'locale'),
          month: any(named: 'month'),
          year: any(named: 'year'),
          generate: captureAny(named: 'generate'),
          cancelToken: any(named: 'cancelToken'),
        )).captured.cast<bool>();

    setUp(() {
      api = _MockApiService();
      connectivity = _MockConnectivity();
      authController = StreamController<bool>.broadcast();
      when(() => api.authStream).thenAnswer((_) => authController.stream);
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      stubBackend();
    });

    tearDown(() => authController.close());

    Widget buildScreen(InsightsCubit cubit, {required bool isActive}) {
      return _buildTestApp(InsightsScreen(cubit: cubit, isActive: isActive));
    }

    InsightsCubit buildCubit() {
      final cubit = InsightsCubit(api: api, connectivity: connectivity);
      addTearDown(cubit.close);
      return cubit;
    }

    testWidgets('неактивная вкладка ничего не запрашивает при смене месяца',
        (tester) async {
      final start = service.period;
      final cubit = buildCubit();

      await tester.pumpWidget(buildScreen(cubit, isActive: false));
      service.previous();
      await tester.pump();

      expect(cubit.selectedMonth, start.month);
      verifyNever(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          ));

      await tester.pumpWidget(buildScreen(cubit, isActive: true));
      await tester.pumpAndSettle();

      // Прошлый месяц при открытии — только запрос сохранённого отчёта.
      expect(cubit.selectedMonth, start.previous.month);
      expect(generateFlags(), [false]);
    });

    testWidgets('текущий месяц при первом открытии генерируется автоматически',
        (tester) async {
      final cubit = buildCubit();

      await tester.pumpWidget(buildScreen(cubit, isActive: true));
      await tester.pumpAndSettle();

      expect(generateFlags(), [true]);
      expect(find.text('Сгенерированный отчёт'), findsOneWidget);
    });

    testWidgets('прошлый месяц без отчёта генерируется только по кнопке',
        (tester) async {
      service.previous();
      final cubit = buildCubit();

      await tester.pumpWidget(buildScreen(cubit, isActive: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('insights_generate_button')),
          findsOneWidget);
      expect(generateFlags(), [false]);

      await tester.tap(find.byKey(const ValueKey('insights_generate_button')));
      await tester.pumpAndSettle();

      expect(generateFlags(), [true]);
      expect(find.text('Сгенерированный отчёт'), findsOneWidget);
    });

    testWidgets('будущий месяц: карточка без запросов и без кнопки',
        (tester) async {
      service.next();
      final cubit = buildCubit();

      await tester.pumpWidget(buildScreen(cubit, isActive: true));
      await tester.pumpAndSettle();

      expect(find.text(LanguageManager.l10n.insights_future_month),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('insights_generate_button')), findsNothing);
      verifyNever(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          ));
    });
  });
}
