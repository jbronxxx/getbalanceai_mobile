import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';

void main() {
  testWidgets('UserAvatar отображает инициалы при отсутствии avatarUrl',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            radius: 24,
            initials: 'AB',
          ),
        ),
      ),
    );

    expect(find.text('AB'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
      'UserAvatar отображает дефолтную иконку при отсутствии avatarUrl и initials',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            radius: 24,
            defaultIcon: Icons.account_circle,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
      'UserAvatar с URL создает Image.network с корректным радиусом и fallback при сбое сети',
      (WidgetTester tester) async {
    const testUrl =
        'https://lh3.googleusercontent.com/a/ACg8ocJ45icLIcSL3o9Xo7SnLJPOeqw3hlMRFz-9FPKfs67a3QOShNk-=s96-c';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            radius: 30,
            avatarUrl: testUrl,
            initials: 'G',
          ),
        ),
      ),
    );

    // Подложка сразу отображает инициалы, не дожидаясь ответа сети
    expect(find.text('G'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // При возникновении сетевой ошибки (в тестах HttpClient возвращает 400)
    // errorBuilder безопасно перехватывает сбой
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('G'), findsOneWidget);
  });
}
