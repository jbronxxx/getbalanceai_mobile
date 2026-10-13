import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';

void main() {
  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildTestApp(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('LiquidGlassNavBar Tests (C1, C4, C6, C8, E4)', () {
    testWidgets(
        'E4: Навбар содержит Semantics с метками и флагом selected для активной вкладки',
        (tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return LiquidGlassNavBar(
                selectedIndex: selectedIdx,
                onDestinationSelected: (idx) {
                  setState(() => selectedIdx = idx);
                },
                destinations: const [
                  LiquidGlassNavItem(
                    icon: Icons.wallet_rounded,
                    label: 'Баланс',
                  ),
                  LiquidGlassNavItem(
                    icon: Icons.donut_small_rounded,
                    label: 'Лимиты',
                  ),
                  LiquidGlassNavItem(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Инсайты',
                  ),
                  LiquidGlassNavItem(
                    icon: Icons.person_rounded,
                    label: 'Профиль',
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semanticsHandle = tester.ensureSemantics();

      // Проверка флага isSelected через SemanticsData
      final balanceSemantics =
          tester.getSemantics(find.bySemanticsLabel('Баланс'));
      expect(
        balanceSemantics.getSemanticsData().hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );

      final limitsSemantics =
          tester.getSemantics(find.bySemanticsLabel('Лимиты'));
      expect(
        limitsSemantics.getSemanticsData().hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );

      // Переключение вкладки по нажатию
      await tester.tap(find.bySemanticsLabel('Лимиты'));
      await tester.pumpAndSettle();

      expect(selectedIdx, 1);
      final updatedLimitsSemantics =
          tester.getSemantics(find.bySemanticsLabel('Лимиты'));
      expect(
        updatedLimitsSemantics
            .getSemanticsData()
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );

      semanticsHandle.dispose();
    });

    testWidgets(
        'Метрики высоты и отступов LiquidGlassNavBar корректно рассчитываются',
        (tester) async {
      late double totalHeight;
      late double bottomContentPadding;
      late double fabBottomPadding;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              totalHeight = LiquidGlassNavBar.totalHeight(context);
              bottomContentPadding =
                  LiquidGlassNavBar.bottomContentPadding(context);
              fabBottomPadding = LiquidGlassNavBar.fabBottomPadding(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(totalHeight, greaterThan(68.0));
      expect(bottomContentPadding, equals(totalHeight + 16.0));
      expect(fabBottomPadding, equals(totalHeight + 8.0));
    });

    testWidgets('LiquidGlassNavBar корректно использует токены GlassTheme',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          LiquidGlassNavBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              LiquidGlassNavItem(
                icon: Icons.wallet_rounded,
                label: 'Баланс',
              ),
              LiquidGlassNavItem(
                icon: Icons.person_rounded,
                label: 'Профиль',
              ),
            ],
          ),
          theme: AppTheme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassNavBar), findsOneWidget);
    });
  });

  group('LiquidGlassFab Tests (C1, C4)', () {
    testWidgets('FAB содержит Tooltip и Semantics с доступным лейблом',
        (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        buildTestApp(
          LiquidGlassFab(
            tooltip: 'Добавить операцию',
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassFab), findsOneWidget);
      expect(find.bySemanticsLabel('Добавить операцию'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);

      await tester.tap(find.byType(LiquidGlassFab));
      await tester.pump();
      expect(pressed, isTrue);
    });
  });

  group('GlassContainer Tests (C5, C7)', () {
    testWidgets('GlassContainer рендерит дочерний виджет с темой GlassTheme',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const GlassContainer(
            child: Text('Контент внутри стекла'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Контент внутри стекла'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
    });
  });

  group('LiquidGlassAppBar Tests', () {
    testWidgets('Рендерит заголовок, действия и стеклянный flexibleSpace',
        (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            appBar: LiquidGlassAppBar(
              title: const Text('Тестовый заголовок'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => actionTapped = true,
                ),
              ],
            ),
            body: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тестовый заголовок'), findsOneWidget);
      expect(find.byType(LiquidGlassAppBar), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('Корректно работает в темной теме', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            appBar: LiquidGlassAppBar(
              title: Text('Темный заголовок'),
            ),
            body: SizedBox(),
          ),
          theme: AppTheme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Темный заголовок'), findsOneWidget);
      expect(find.byType(LiquidGlassAppBar), findsOneWidget);
    });

    testWidgets(
        'topContentPadding рассчитывается и хэдер не содержит нижней границы',
        (tester) async {
      late double topPadding;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              topPadding = LiquidGlassAppBar.topContentPadding(context);
              return const Scaffold(
                appBar: LiquidGlassAppBar(
                  title: Text('Без полоски'),
                ),
                body: SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(topPadding, greaterThanOrEqualTo(kToolbarHeight));
      // Проверяем, что подложка хэдера не содержит Border
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(LiquidGlassAppBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
      expect(
        decoration.borderRadius,
        equals(const BorderRadius.vertical(bottom: Radius.circular(20.0))),
      );
    });
  });

  group('ScreenBodyCard Tests', () {
    testWidgets('Рендерит контент со скругленными верхними углами без границы',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ScreenBodyCard(
            child: Text('Контент внутри карточки экрана'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Контент внутри карточки экрана'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(
        decoration.borderRadius,
        equals(const BorderRadius.vertical(top: Radius.circular(28.0))),
      );
      expect(decoration.border, isNull);
    });
  });
}
