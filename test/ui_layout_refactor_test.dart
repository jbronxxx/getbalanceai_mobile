import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/screens/debug_menu_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';

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

  group('AppTheme Tests', () {
    test('Light theme properties', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppTheme.primaryTeal);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.cardTheme.color, AppTheme.lightCardBg);
      expect(theme.floatingActionButtonTheme.backgroundColor,
          AppTheme.primaryTeal);
    });

    test('Dark theme properties', () {
      final theme = AppTheme.darkTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppTheme.primaryTeal);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.cardTheme.color, AppTheme.darkCardBg);
      expect(theme.floatingActionButtonTheme.backgroundColor,
          AppTheme.primaryTeal);
    });
  });

  group('ProfileAppVersion Tests', () {
    testWidgets('Renders localized version label', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ProfileAppVersion(appVersion: '1.2.3+45'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Версия 1.2.3+45'), findsOneWidget);
    });

    testWidgets(
        'Tapping less than 5 times does not show any snackbar and resets after 2 seconds',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ProfileAppVersion(appVersion: '1.2.3+45'),
        ),
      );
      await tester.pumpAndSettle();

      final versionFinder = find.byType(ProfileAppVersion);

      // Tapping 1 to 4 times does not show any snackbar
      for (int i = 0; i < 4; i++) {
        await tester.tap(versionFinder);
        await tester.pump();
      }
      expect(find.byType(SnackBar), findsNothing);

      // Wait 2s for reset timer to fire
      await tester.pump(const Duration(milliseconds: 2100));

      // Tapping again once does not show snackbar
      await tester.tap(versionFinder);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Tapping 5 times navigates to DebugMenuScreen', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ProfileAppVersion(appVersion: '1.2.3+45'),
        ),
      );
      await tester.pumpAndSettle();

      final versionFinder = find.byType(ProfileAppVersion);

      for (int i = 0; i < 5; i++) {
        await tester.tap(versionFinder);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.byType(DebugMenuScreen), findsOneWidget);
    });
  });

  group('Budgets Widgets Tests', () {
    testWidgets('BudgetPeriodSelector triggers callbacks on change',
        (tester) async {
      int changedMonth = 0;

      await tester.pumpWidget(
        _buildTestApp(
          BudgetPeriodSelector(
            selectedMonth: 5,
            selectedYear: 2026,
            onMonthChanged: (m) => changedMonth = m,
            onYearChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(LanguageManager.monthsNames[4]), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      // Change month to month 6 (June)
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(LanguageManager.monthsNames[5]).last);
      await tester.pumpAndSettle();
      expect(changedMonth, 6);
    });

    testWidgets('BudgetItemCard renders progress and exceeded alert',
        (tester) async {
      final budget = Budget(
        localId: 1,
        dbCategory: Category.food.name,
        limitAmount: 1000,
        month: 5,
        year: 2026,
        spent: 0,
        remaining: 1000,
      );

      // Test under budget
      await tester.pumpWidget(
        _buildTestApp(
          BudgetItemCard(
            budget: budget,
            currentSpent: 500,
            isFirst: false,
            showSwipeHint: false,
            onTap: () {},
            onDelete: () {},
            onHintShown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Питание'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Превышен'), findsNothing);

      // Test exceeded budget
      await tester.pumpWidget(
        _buildTestApp(
          BudgetItemCard(
            budget: budget,
            currentSpent: 1200,
            isFirst: false,
            showSwipeHint: false,
            onTap: () {},
            onDelete: () {},
            onHintShown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Превышен'), findsOneWidget);
    });

    testWidgets(
        'BudgetItemCard handles very large amounts without overflow and maintains category spacing',
        (tester) async {
      final largeBudget = Budget(
        localId: 2,
        dbCategory: Category.entertainment.name,
        limitAmount: 500000000,
        month: 5,
        year: 2026,
        spent: 250000000,
        remaining: 250000000,
      );

      await tester.pumpWidget(
        _buildTestApp(
          BudgetItemCard(
            budget: largeBudget,
            currentSpent: 250000000,
            isFirst: false,
            showSwipeHint: false,
            onTap: () {},
            onDelete: () {},
            onHintShown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Развлечения'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Dashboard Widgets Tests', () {
    testWidgets('GuestModeBanner renders notice correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const GuestModeBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.textContaining('Гостевой режим'), findsOneWidget);
    });

    testWidgets('TransactionItemTile displays description and formats amount',
        (tester) async {
      final date = DateTime(2026, 5, 10);
      final transaction = Transaction(
        localId: 10,
        amount: 250,
        dbType: TransactionType.expense.name,
        dbCategory: Category.food.name,
        dateMilliseconds: date.millisecondsSinceEpoch,
        dateCreatedMilliseconds: date.millisecondsSinceEpoch,
        description: 'Обед в кафе',
      );

      bool tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          TransactionItemTile(
            transaction: transaction,
            onTap: () => tapped = true,
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Обед в кафе'), findsOneWidget);
      expect(find.textContaining('250'), findsOneWidget);

      await tester.tap(find.text('Обед в кафе'));
      expect(tapped, isTrue);
    });
  });

  group('WelcomeLanguageSheet Tests', () {
    testWidgets('WelcomeLanguageSheet renders options and button',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const WelcomeLanguageSheet()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('O\'zbekcha'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('AddTransactionSheet Tests', () {
    testWidgets(
        'AddTransactionSheet has no close button and uses SingleChildScrollView to avoid keyboard overflow',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AddTransactionSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(LanguageManager.l10n.new_transaction), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BalanceCard Tests', () {
    testWidgets('BalanceCard renders amounts and income/expense containers',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const BalanceCard(
            balance: 150000,
            income: 200000,
            expense: 50000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(LanguageManager.l10n.total_balance), findsOneWidget);
      expect(find.text(LanguageManager.l10n.income_title), findsOneWidget);
      expect(find.text(LanguageManager.l10n.expense_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
