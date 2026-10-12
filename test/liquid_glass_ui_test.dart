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
}
