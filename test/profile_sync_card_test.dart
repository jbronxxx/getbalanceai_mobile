import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/profile/profile_cubit.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile_sync_card.dart';
import 'package:getbalanceai_mobile/widgets/profile/sync_rejected_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget body) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: body),
  );
}

Widget _card({
  required SyncStatus status,
  int pendingCount = 0,
  int rejectedCount = 0,
  bool isAuthenticated = true,
  VoidCallback? onSyncPressed,
  VoidCallback? onRejectedPressed,
}) {
  return _app(
    ProfileSyncCard(
      isAuthenticated: isAuthenticated,
      status: status,
      pendingCount: pendingCount,
      rejectedCount: rejectedCount,
      onSyncPressed: onSyncPressed ?? () {},
      onRejectedPressed: onRejectedPressed,
    ),
  );
}

Transaction _transaction({
  required String? rejectCode,
  String description = 'Кофе',
}) =>
    Transaction(
      localId: 1,
      amount: 12,
      description: description,
      dbCategory: 'food',
      dbType: 'expense',
      dateMilliseconds: DateTime(2025, 9, 30).millisecondsSinceEpoch,
      dateCreatedMilliseconds: DateTime(2025, 9, 30).millisecondsSinceEpoch,
      currencyCode: 'USD',
      isModified: true,
      syncRejectCode: rejectCode,
    );

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

  group('Отклонённые сервером записи', () {
    const rejectedText = 'Сервер не принял: 2';

    testWidgets('строка видна, тап по ней открывает список, а не синк',
        (tester) async {
      var syncTaps = 0;
      var rejectedTaps = 0;
      await tester.pumpWidget(_card(
        status: SyncStatus.success,
        pendingCount: 3,
        rejectedCount: 2,
        onSyncPressed: () => syncTaps++,
        onRejectedPressed: () => rejectedTaps++,
      ));

      expect(find.text(pendingText), findsOneWidget);
      expect(find.text(rejectedText), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sync_rejected_link')));
      expect(rejectedTaps, 1);
      expect(syncTaps, 0);

      await tester.tap(find.text(pendingText));
      expect(syncTaps, 1);
      expect(rejectedTaps, 1);
    });

    testWidgets('без отклонённых и без входа строки нет', (tester) async {
      await tester.pumpWidget(_card(status: SyncStatus.idle, pendingCount: 3));
      expect(find.byKey(const ValueKey('sync_rejected_link')), findsNothing);

      await tester.pumpWidget(_card(
        status: SyncStatus.idle,
        rejectedCount: 2,
        isAuthenticated: false,
      ));
      expect(find.byKey(const ValueKey('sync_rejected_link')), findsNothing);
    });

    test('причина по коду сервера', () {
      final l10n = LanguageManager.l10n;
      String reason(String code) => SyncRejectedSheet.reasonText(
            l10n,
            _transaction(rejectCode: code),
          );

      expect(reason('INVALID_CURRENCY'), 'Сервер не смог получить курс валюты');
      expect(reason('INVALID_TRANSACTION_AMOUNT'),
          'Сумма в основной валюте слишком большая');
      expect(
          reason(Transaction.unknownRejectCode), 'Сервер не принял эту запись');
      expect(reason('NEW_SERVER_CODE'), 'Сервер не принял эту запись');
    });

    testWidgets('лист показывает запись с причиной и возвращает её по тапу',
        (tester) async {
      final transaction = _transaction(
        rejectCode: 'INVALID_TRANSACTION_AMOUNT',
        description: 'Ноутбук',
      );
      Transaction? picked;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await showModalBottomSheet<Transaction>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SyncRejectedSheet(transactions: [transaction]),
            );
          },
          child: const Text('open'),
        ),
      )));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Не принято сервером'), findsOneWidget);
      expect(find.text('Питание'), findsOneWidget);
      expect(find.textContaining('Ноутбук'), findsOneWidget);
      expect(
          find.text('Сумма в основной валюте слишком большая'), findsOneWidget);

      await tester.tap(find.text('Питание'));
      await tester.pumpAndSettle();

      expect(picked, same(transaction));
      expect(find.text('Не принято сервером'), findsNothing);
    });
  });
}
