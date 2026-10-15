import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';

Widget _buildTestApp(Widget child, {Locale locale = const Locale('ru')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    EnvironmentConfig.clearListenersForTesting();
    dotenv.testLoad(fileInput: '''
PROD_API_BASE_URL=https://prod.example.com/api/v1
DEV_API_BASE_URL=https://dev.example.com/api/v1
API_BASE_URL=http://localhost:8000/api/v1
''');
    await EnvironmentConfig.init();
    AppInfoService.instance.reset();
    PackageInfo.setMockInitialValues(
      appName: 'FinanceApp',
      packageName: 'com.finance.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  tearDown(() {
    EnvironmentConfig.clearListenersForTesting();
    AppInfoService.instance.reset();
  });

  group('Input Validation Theme Tests', () {
    test(
        'AppTheme light and dark define red errorBorder and focusedErrorBorder',
        () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      expect(lightTheme.inputDecorationTheme.errorBorder, isNotNull);
      expect(lightTheme.inputDecorationTheme.errorBorder?.borderSide.color,
          AppTheme.errorRed);
      expect(
          lightTheme.inputDecorationTheme.focusedErrorBorder?.borderSide.color,
          AppTheme.errorRed);
      expect(
          lightTheme.inputDecorationTheme.errorStyle?.color, AppTheme.errorRed);

      expect(darkTheme.inputDecorationTheme.errorBorder, isNotNull);
      expect(darkTheme.inputDecorationTheme.errorBorder?.borderSide.color,
          AppTheme.errorRed);
      expect(
          darkTheme.inputDecorationTheme.focusedErrorBorder?.borderSide.color,
          AppTheme.errorRed);
      expect(
          darkTheme.inputDecorationTheme.errorStyle?.color, AppTheme.errorRed);
    });
  });

  group('AddTransactionSheet Validation Tests', () {
    testWidgets('Empty amount shows inline error text and no alert snackbar',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const AddTransactionSheet()),
      );
      await tester.pumpAndSettle();

      final addButton = find.text(LanguageManager.l10n.add_btn);
      await tester.ensureVisible(addButton);
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.decoration?.errorText,
          LanguageManager.l10n.amount_requirement_enter);
    });

    testWidgets('Amount <= 0 shows positive amount requirement',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const AddTransactionSheet()),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, '0');
      await tester.pump();

      final addButton = find.text(LanguageManager.l10n.add_btn);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(LanguageManager.l10n.amount_requirement_positive),
          findsOneWidget);
    });

    testWidgets('Amount exceeding limit shows max requirement message',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const AddTransactionSheet()),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, '200000000');
      await tester.pump();

      final addButton = find.text(LanguageManager.l10n.add_btn);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      final expectedMax = LanguageManager.l10n.amount_requirement_max(
        CurrencyFormatter.format(CurrencyFormatter.currentCurrency.maxAmount,
            showSymbol: false),
        CurrencyFormatter.currentCurrency.code,
      );
      expect(find.text(expectedMax), findsOneWidget);
    });

    testWidgets('Typing in amount clears the error message', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const AddTransactionSheet()),
      );
      await tester.pumpAndSettle();

      final addButton = find.text(LanguageManager.l10n.add_btn);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();

      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsOneWidget);

      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, '500');
      await tester.pump();

      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsNothing);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.errorText, isNull);
    });
  });

  group('AddBudgetSheet Validation Tests', () {
    testWidgets('Empty amount shows inline error text and no alert snackbar',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.text(LanguageManager.l10n.save_btn);
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.decoration?.errorText,
          LanguageManager.l10n.amount_requirement_enter);
    });

    testWidgets('Amount <= 0 shows positive amount requirement',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, '0');
      await tester.pump();

      final saveButton = find.text(LanguageManager.l10n.save_btn);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(LanguageManager.l10n.amount_requirement_positive),
          findsOneWidget);
    });

    testWidgets('Typing in budget amount clears the error', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AddBudgetSheet(
            selectedMonth: 10,
            selectedYear: 2026,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.text(LanguageManager.l10n.save_btn);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsOneWidget);

      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, '1000');
      await tester.pump();

      expect(find.text(LanguageManager.l10n.amount_requirement_enter),
          findsNothing);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.errorText, isNull);
    });
  });
}
