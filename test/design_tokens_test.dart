import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/widgets/app_sheet.dart';

/// Контраст по WCAG 2.1: (L1 + 0.05) / (L2 + 0.05).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppColors в темах', () {
    test('обе темы регистрируют расширение', () {
      expect(AppTheme.lightTheme.extension<AppColors>(), AppColors.light);
      expect(AppTheme.darkTheme.extension<AppColors>(), AppColors.dark);
    });

    for (final entry in {
      'светлая': (GlassTheme.light, AppColors.light),
      'тёмная': (GlassTheme.dark, AppColors.dark),
    }.entries) {
      test('${entry.key}: граница тоста видна на стекле и на фоне (≥ 3:1)', () {
        final (glass, colors) = entry.value;
        final toast =
            Color.alphaBlend(glass.toastSurface, colors.shellBackground);
        final rim = Color.alphaBlend(glass.toastRim, toast);
        expect(_contrast(rim, toast), greaterThanOrEqualTo(3));
        expect(_contrast(rim, colors.shellBackground), greaterThanOrEqualTo(3));
      });
    }

    test('обе темы используют InkRipple вместо зернистого InkSparkle', () {
      expect(AppTheme.lightTheme.splashFactory, InkRipple.splashFactory);
      expect(AppTheme.darkTheme.splashFactory, InkRipple.splashFactory);
    });

    for (final entry in {
      'светлая': AppColors.light,
      'тёмная': AppColors.dark,
    }.entries) {
      test('${entry.key}: бирюзовый текст читается (WCAG AA ≥ 4.5)', () {
        final c = entry.value;
        expect(_contrast(c.accentText, c.shellBackground),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(c.accentText, c.cardBackground),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(c.accentText, c.sheetBackground),
            greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: предупреждение и перерасход читаются на карточке',
          () {
        final c = entry.value;
        expect(
            _contrast(c.warning, c.cardBackground), greaterThanOrEqualTo(4.5));
        expect(
            _contrast(c.exceeded, c.cardBackground), greaterThanOrEqualTo(4.5));
        // Карточка перерасхода подкрашена тем же цветом (8% / 16%)
        final tinted = Color.alphaBlend(
          c.exceeded.withValues(alpha: entry.key == 'тёмная' ? 0.16 : 0.08),
          c.cardBackground,
        );
        expect(_contrast(c.exceeded, tinted), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: текст на фирменной карточке читается', () {
        final c = entry.value;
        expect(_contrast(c.onBrand, c.brandGradientStart),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(c.onBrand, c.brandGradientEnd),
            greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('без расширения в теме — значения по яркости темы',
        (tester) async {
      // Изолированные тесты виджетов часто собирают ThemeData без расширений.
      late AppColors resolved;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          resolved = AppColors.of(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(identical(resolved, AppColors.dark), isTrue);
    });
  });

  group('AppSheet', () {
    testWidgets('оформление листа берётся из токенов текущей темы',
        (tester) async {
      late BoxDecoration decoration;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(builder: (context) {
          decoration = AppSheet.decoration(context);
          return const Scaffold(body: SheetHandle());
        }),
      ));

      expect(decoration.color, AppColors.dark.sheetBackground);
      expect(decoration.boxShadow!.single.color, AppColors.dark.sheetShadow);
      final handle = tester.widget<Container>(
        find.descendant(
          of: find.byType(SheetHandle),
          matching: find.byType(Container),
        ),
      );
      expect((handle.decoration! as BoxDecoration).color,
          AppColors.dark.sheetHandleDark);
    });
  });
}
