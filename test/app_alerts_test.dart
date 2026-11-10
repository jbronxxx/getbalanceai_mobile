import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/widgets/app_alerts.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';

void main() {
  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('AppAlerts.success shows SnackBar with text and no icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              AppAlerts.success(context, 'Успешная операция');
            },
            child: const Text('Show Alert'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Alert'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Let it settle

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Успешная операция'), findsOneWidget);
    // Сообщения без иконок
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('AppAlerts.error shows SnackBar without icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              AppAlerts.error(context, 'Ошибка сервера', title: 'Внимание');
            },
            child: const Text('Show Alert'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Внимание'), findsOneWidget); // Title should be visible
    expect(find.text('Ошибка сервера'), findsOneWidget);
    // Сообщения без иконок
    expect(find.byIcon(Icons.error_rounded), findsNothing);
  });

  testWidgets('AppAlerts.noInternet shows unified network error message',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              AppAlerts.noInternet(context);
            },
            child: const Text('Show Alert'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);

    // Check if the unified text from LanguageManager is shown
    final expectedText = LanguageManager.l10n.no_internet_connection;
    expect(find.text(expectedText), findsOneWidget);
    // Сообщения без иконок
    expect(find.byIcon(Icons.warning_rounded), findsNothing);
  });

  testWidgets(
      'AppAlerts.showConfirmDialog renders dialog content and handles cancel/confirm',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              dialogResult = await AppAlerts.showConfirmDialog(
                context,
                title: 'Выйти из аккаунта?',
                message: 'Вы уверены, что хотите выйти?',
                confirmText: 'Выйти',
                cancelText: 'Отмена',
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ));

    // Нажатие для открытия диалога
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    expect(find.text('Вы уверены, что хотите выйти?'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
    // Сообщения без иконок
    expect(find.byIcon(Icons.logout_rounded), findsNothing);

    // Нажатие Отмена
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(dialogResult, isFalse);
    expect(find.text('Выйти из аккаунта?'), findsNothing);

    // Повторное открытие для проверки подтверждения
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
    expect(find.text('Выйти из аккаунта?'), findsNothing);
  });

  testWidgets(
      'AppAlerts.showConfirmDialog destructive styling renders correctly',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              dialogResult = await AppAlerts.showConfirmDialog(
                context,
                title: 'Удалить аккаунт?',
                message: 'Это действие необратимо.',
                confirmText: 'Удалить',
                isDestructive: true,
              );
            },
            child: const Text('Show Destructive Dialog'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Destructive Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить аккаунт?'), findsOneWidget);
    expect(find.text('Это действие необратимо.'), findsOneWidget);
    // Сообщения без иконок
    expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
  });

  testWidgets(
      'AppAlerts.showConfirmDialog adaptively handles long button texts without overflow',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              dialogResult = await AppAlerts.showConfirmDialog(
                context,
                title: 'Выход',
                message: 'Вы уверены, что хотите выйти из аккаунта?',
                confirmText: 'Выйти из аккаунта',
                cancelText: 'Отмена',
              );
            },
            child: const Text('Show Long Text Dialog'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Long Text Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);

    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
  });
}
