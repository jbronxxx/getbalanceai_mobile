import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:getbalanceai_mobile/services/app_info_service.dart';
import 'package:getbalanceai_mobile/widgets/swipe_hint_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppInfoService Tests', () {
    setUp(() {
      AppInfoService.instance.reset();
      PackageInfo.setMockInitialValues(
        appName: 'GetBalance',
        packageName: 'com.getbalanceai.mobile',
        version: '1.2.3',
        buildNumber: '42',
        buildSignature: '',
      );
    });

    tearDown(() {
      AppInfoService.instance.reset();
    });

    test('returns correct version string and cached package info', () async {
      final versionStr = await AppInfoService.instance.getVersionString();
      expect(versionStr, '1.2.3+42');

      final appName = await AppInfoService.instance.getAppName();
      expect(appName, 'GetBalance');

      final packageName = await AppInfoService.instance.getPackageName();
      expect(packageName, 'com.getbalanceai.mobile');

      final info = await AppInfoService.instance.getPackageInfo();
      expect(info.version, '1.2.3');
      expect(info.buildNumber, '42');
    });

    test('reset clears cache and allows setting mock info', () async {
      final mock = PackageInfo(
        appName: 'MockApp',
        packageName: 'com.mock.app',
        version: '2.0.0',
        buildNumber: '99',
        buildSignature: '',
      );

      AppInfoService.instance.setMockPackageInfo(mock);
      expect(await AppInfoService.instance.getVersionString(), '2.0.0+99');
      expect(await AppInfoService.instance.getAppName(), 'MockApp');

      AppInfoService.instance.reset();
      // After reset, falls back to platform mock values
      expect(await AppInfoService.instance.getVersionString(), '1.2.3+42');
    });
  });

  group('SwipeHintWrapper Widget Tests', () {
    testWidgets('renders child directly when showHint is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SwipeHintWrapper(
              showHint: false,
              child: Text('Test Item'),
            ),
          ),
        ),
      );

      expect(find.text('Test Item'), findsOneWidget);
      expect(_hintSlide(), findsNothing);
    });

    testWidgets('triggers onHintShown and animates when showHint is true',
        (tester) async {
      bool hintShownCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeHintWrapper(
              showHint: true,
              onHintShown: () {
                hintShownCalled = true;
              },
              child: const Text('Hint Item'),
            ),
          ),
        ),
      );

      expect(hintShownCalled, isTrue);
      expect(_hintSlide(), findsOneWidget);

      // Fast-forward past the 800ms start delay and 1200ms animation
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Hint Item'), findsOneWidget);
    });

    testWidgets('disposes cleanly before delay expires without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SwipeHintWrapper(
              showHint: true,
              child: Text('Disposable Item'),
            ),
          ),
        ),
      );

      // Advance by 200ms (before the 800ms timer fires)
      await tester.pump(const Duration(milliseconds: 200));

      // Unmount the widget by replacing it
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Replacement'),
          ),
        ),
      );

      // Advance beyond 800ms to ensure no unmounted controller calls or exceptions occur
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Replacement'), findsOneWidget);
    });
  });
}

/// Сдвиг подсказки внутри обёртки (у перехода маршрута свои SlideTransition).
Finder _hintSlide() => find.descendant(
      of: find.byType(SwipeHintWrapper),
      matching: find.byType(SlideTransition),
    );
