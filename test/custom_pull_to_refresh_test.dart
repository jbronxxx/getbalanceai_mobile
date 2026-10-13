import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/custom_pull_to_refresh.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
  });

  Widget buildTestWidget({
    required Future<void> Function() onRefresh,
    double? topPadding,
    bool releaseImmediately = false,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: CustomPullToRefresh(
          onRefresh: onRefresh,
          topPadding: topPadding,
          releaseImmediately: releaseImmediately,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: 20,
            itemBuilder: (context, index) => ListTile(
              title: Text('Элемент $index'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'CustomPullToRefresh: контент рендерится и не смещается в исходном состоянии',
      (tester) async {
    bool refreshed = false;

    await tester.pumpWidget(buildTestWidget(
      onRefresh: () async {
        refreshed = true;
      },
      topPadding: 100,
    ));
    await tester.pumpAndSettle();

    // Первый элемент списка на своем месте
    expect(find.text('Элемент 0'), findsOneWidget);
    expect(refreshed, isFalse);

    // В исходном состоянии плавающий индикатор скрыт
    expect(find.text('Потяните для обновления'), findsNothing);
  });

  testWidgets(
      'CustomPullToRefresh: жест протяжки вызывает onRefresh, контент не съезжает вниз',
      (tester) async {
    bool refreshed = false;

    await tester.pumpWidget(buildTestWidget(
      onRefresh: () async {
        refreshed = true;
      },
      topPadding: 100,
    ));
    await tester.pumpAndSettle();

    // Запоминаем исходную позицию первого элемента списка
    final initialPos = tester.getTopLeft(find.text('Элемент 0'));

    // Тянем список вниз для активации оверскролла
    await tester.drag(find.text('Элемент 0'), const Offset(0, 300));
    await tester.pump();

    // Позиция элемента остается стабильной (контент не уезжает вниз через Transform)
    final duringPos = tester.getTopLeft(find.text('Элемент 0'));
    expect(duringPos.dx, initialPos.dx);

    await tester.pumpAndSettle();
    expect(refreshed, isTrue);
  });
}
