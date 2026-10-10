import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/screens/debug_menu_screen.dart';
import 'package:getbalanceai_mobile/services/app_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    EnvironmentConfig.clearListenersForTesting();
    AppInfoService.instance.reset();
  });

  testWidgets(
      'DebugMenuScreen renders titles, environment, version and buttons',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DebugMenuScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debug Menu'), findsOneWidget);
    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('App Info'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Version: 1.0.0+1'), findsOneWidget);
    expect(
        find.text('Base URL: https://dev.example.com/api/v1'), findsOneWidget);
    expect(find.text('Open Logs (Talker)'), findsOneWidget);
    expect(find.text('Clear Cache & Tokens'), findsOneWidget);
  });

  testWidgets('DebugMenuScreen changes environment via dropdown',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DebugMenuScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Открываем DropdownButton
    await tester.tap(find.byType(DropdownButton<Environment>));
    await tester.pumpAndSettle();

    // Выбираем LOCAL
    final localItem = find.text('LOCAL').last;
    await tester.tap(localItem);
    await tester.pumpAndSettle();

    expect(EnvironmentConfig.current, Environment.local);
    expect(find.text('Environment changed to LOCAL. Session reset.'),
        findsOneWidget);
  });

  testWidgets('DebugMenuScreen clears cache and tokens on button press',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DebugMenuScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear Cache & Tokens'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Cache & Tokens cleared'), findsOneWidget);
  });

  testWidgets('DebugMenuScreen opens TalkerScreen on button press',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DebugMenuScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Logs (Talker)'));
    await tester.pumpAndSettle();

    expect(find.byType(TalkerScreen), findsOneWidget);
  });
}
