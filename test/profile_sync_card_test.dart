import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/profile/profile_cubit.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile_sync_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _card({required SyncStatus status, int pendingCount = 0}) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: ProfileSyncCard(
        isAuthenticated: true,
        status: status,
        pendingCount: pendingCount,
        onSyncPressed: () {},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
  });

  const pendingText = 'Не отправлено: 3. Нажмите, чтобы отправить';

  testWidgets('без неотправленных изменений — «Данные синхронизированы»',
      (tester) async {
    await tester.pumpWidget(_card(status: SyncStatus.idle));

    expect(find.text('Данные синхронизированы'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
  });

  for (final status in [SyncStatus.idle, SyncStatus.success]) {
    testWidgets('есть неотправленные (${status.name}) — показывает их число',
        (tester) async {
      await tester.pumpWidget(_card(status: status, pendingCount: 3));

      expect(find.text(pendingText), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);
    });
  }

  testWidgets('во время синхронизации и при ошибке счётчик не показывается',
      (tester) async {
    await tester.pumpWidget(_card(status: SyncStatus.syncing, pendingCount: 3));
    expect(find.text(pendingText), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_card(status: SyncStatus.error, pendingCount: 3));
    expect(find.text(pendingText), findsNothing);
    expect(find.text('Ошибка синхронизации'), findsOneWidget);
  });
}
