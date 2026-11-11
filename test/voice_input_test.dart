import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/screens/voice_input_flow.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/services/speech_input_service.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/widgets/voice_listening_sheet.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';

import 'support/fake_speech_recognizer.dart';

/// FEAT-01: голосовой ввод — разбор ответа сервера, шторка «Говорите»,
/// список распознанных записей, долгое нажатие на «+», подсказка.
void main() {
  late FakeSpeechRecognizer speech;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('voice_input');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
    LanguageManager.initFallback();
    await LocalDbService.init();
  });

  setUp(() async {
    // Подсказки свайпа уже показаны: анимация не мешает жестам в тестах
    SharedPreferences.setMockInitialValues({'ux_hint_sessions_completed': 3});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await LocalDbService.instance.clearAllData();
    await CurrencyFormatter.setCurrency(Currency.eur);
    SelectedPeriodService.instance.select(MonthPeriod.current());
    speech = FakeSpeechRecognizer();
    SpeechInput.recognizer = speech;
  });

  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  final yesterday = today.subtract(const Duration(days: 1));

  Transaction draft(
    int id,
    String description,
    double amount, {
    DateTime? date,
    Category category = Category.food,
  }) =>
      Transaction.newRecord(
        localId: id,
        type: TransactionType.expense,
        category: category,
        amount: amount,
        currency: Currency.eur,
        date: date ?? now,
        description: description,
      );

  Widget app(Widget home) => MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: home,
      );

  /// Экран с кнопкой «open», по которой вызывается [action].
  Widget host(Future<void> Function(BuildContext context) action) =>
      app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => action(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Разбор ответа сервера', () {
    test('черновики: суммы-строки, день со временем «сейчас», id по порядку',
        () {
      final clock = DateTime(2026, 11, 11, 14, 30, 5);
      final drafts = VoiceDrafts.fromJson({
        'records': [
          {
            'type': 'expense',
            'category': 'food',
            'amount': '4.50',
            'currency': 'EUR',
            'description': ' Кофе ',
            'date': '2026-11-11',
          },
          {
            'type': 'income',
            'category': 'salary',
            'amount': '1500.00',
            'currency': 'USD',
            'description': '',
            'date': '2026-11-10',
          },
          {'type': 'expense', 'category': 'food', 'amount': '0.00'},
          'мусор',
          {
            'type': 'expense',
            'category': 'transport',
            'amount': 12,
            'currency': 'GBP',
            'date': 'вчера',
          },
        ],
      }, now: clock);

      expect(drafts.map((d) => d.localId), [1, 2, 3]);
      expect(drafts[0].amount, 4.5);
      expect(drafts[0].description, 'Кофе');
      expect(drafts[0].date, DateTime(2026, 11, 11, 14, 30, 5));
      expect(drafts[1].type, TransactionType.income);
      expect(drafts[1].category, Category.salary);
      expect(drafts[1].currency, Currency.usd);
      expect(drafts[1].date, DateTime(2026, 11, 10, 14, 30, 5));
      // Неизвестная валюта — валюта приложения, дата не разобрана — сейчас
      expect(drafts[2].currency, Currency.eur);
      expect(drafts[2].date, clock);
      expect(drafts.every((d) => d.serverId == null), isTrue);
    });

    test('ответ без списка — пусто', () {
      expect(VoiceDrafts.fromJson({'records': null}), isEmpty);
      expect(VoiceDrafts.fromJson({}), isEmpty);
    });
  });

  group('Локаль распознавания', () {
    test('страна — из системы, если язык тот же, иначе основная', () {
      expect(
          SpeechInput.localeIdFor('ru', systemLocale: const Locale('ru', 'RU')),
          'ru_RU');
      expect(
          SpeechInput.localeIdFor('en', systemLocale: const Locale('en', 'GB')),
          'en_GB');
      expect(
          SpeechInput.localeIdFor('en', systemLocale: const Locale('ru', 'RU')),
          'en_US');
      expect(SpeechInput.localeIdFor('ru', systemLocale: const Locale('ru')),
          'ru_RU');
    });
  });

  group('Подсказка «удерживайте +»', () {
    Future<bool> launch() {
      PreferencesService.instance.resetVoiceHintTurn();
      return PreferencesService.instance.takeVoiceHintTurn();
    }

    test('после первого входа, затем каждый 5-й запуск', () async {
      SharedPreferences.setMockInitialValues({});
      final shown = [for (var i = 0; i < 11; i++) await launch()];
      expect(shown, [
        true, // первый показ после входа
        false, false, false, false, true, // 5-й запуск
        false, false, false, false, true,
      ]);
    });

    test('один раз за запуск', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await launch(), isTrue);
      expect(await PreferencesService.instance.takeVoiceHintTurn(), isFalse);
    });

    test('после первого голосового ввода — больше никогда', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await launch(), isTrue);
      await PreferencesService.instance.recordVoiceInputUsed();
      for (var i = 0; i < 6; i++) {
        expect(await launch(), isFalse);
      }
    });
  });

  group('Шторка «Говорите»', () {
    late List<String> parsed;
    late Future<List<Transaction>> Function(String) parseResult;
    VoiceInputResult? result;
    var closed = false;

    setUp(() {
      parsed = [];
      parseResult = (_) async => [draft(1, 'Кофе', 4)];
      result = null;
      closed = false;
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(host((context) async {
        result = await VoiceListeningSheet.show(context, parse: (phrase) {
          parsed.add(phrase);
          return parseResult(phrase);
        });
        closed = true;
      }));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    String message(WidgetTester tester) => tester
        .widget<WholeWordsText>(find.byKey(const ValueKey('voice_message')))
        .text;

    testWidgets('текст вживую, итоговая фраза уходит в разбор', (tester) async {
      await open(tester);
      expect(find.text('Говорите'), findsOneWidget);
      expect(speech.localeId, startsWith('ru_'));
      expect(find.byKey(const ValueKey('voice_level')), findsOneWidget);

      speech.say('кофе четыре');
      speech.level(0.8);
      await tester.pump();
      expect(find.text('кофе четыре'), findsOneWidget);

      speech.say(' кофе четыре евро ', isFinal: true);
      await settle(tester);
      expect(parsed, ['кофе четыре евро']);
      expect(closed, isTrue);
      expect(result!.phrase, 'кофе четыре евро');
      expect(result!.drafts.single.description, 'Кофе');
    });

    testWidgets('«Готово» без итогового текста — берётся распознанное',
        (tester) async {
      await open(tester);
      speech.say('такси двенадцать');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('voice_done')));
      await tester.pump();
      expect(speech.stopCalls, 1);
      expect(parsed, isEmpty);

      await tester.pump(VoiceListeningSheet.finalResultWait);
      await settle(tester);
      expect(parsed, ['такси двенадцать']);
    });

    testWidgets('«Разбираю фразу…» до ответа сервера', (tester) async {
      final pending = Completer<List<Transaction>>();
      parseResult = (_) => pending.future;
      await open(tester);
      speech.say('кофе 4 евро', isFinal: true);
      await tester.pump();
      expect(find.text('Разбираю фразу…'), findsOneWidget);
      expect(find.text('кофе 4 евро'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_done')), findsNothing);

      pending.complete([draft(1, 'Кофе', 4)]);
      await settle(tester);
      expect(closed, isTrue);
    });

    testWidgets('ничего не услышал — «Сказать ещё раз» слушает снова',
        (tester) async {
      await open(tester);
      speech.say('', isFinal: true);
      await settle(tester);
      expect(message(tester), startsWith('Ничего не услышал'));
      expect(parsed, isEmpty);

      await tester.tap(find.byKey(const ValueKey('voice_retry')));
      await settle(tester);
      expect(speech.listenCalls, 2);
      expect(find.text('Говорите'), findsOneWidget);
    });

    testWidgets('сбой распознавания — с повтором', (tester) async {
      await open(tester);
      speech.fail(SpeechFailure.failed);
      await settle(tester);
      expect(message(tester), startsWith('Не удалось распознать речь'));
      expect(find.byKey(const ValueKey('voice_retry')), findsOneWidget);
    });

    testWidgets('нет доступа к микрофону — только «Закрыть»', (tester) async {
      speech.prepareFailure = SpeechFailure.permissionDenied;
      await open(tester);
      expect(message(tester), startsWith('Нет доступа к микрофону'));
      expect(speech.listenCalls, 0);
      expect(find.byKey(const ValueKey('voice_retry')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('voice_close')));
      await settle(tester);
      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('в фразе нет суммы', (tester) async {
      parseResult = (_) async => [];
      await open(tester);
      speech.say('привет', isFinal: true);
      await settle(tester);
      expect(message(tester), startsWith('Не нашёл в фразе суммы'));
      expect(closed, isFalse);
    });

    DioException serverError(int status, String code) => DioException(
          requestOptions: RequestOptions(path: '/voice/parse'),
          response: Response(
            requestOptions: RequestOptions(path: '/voice/parse'),
            statusCode: status,
            data: {'status': 'error', 'code': code, 'message': 'текст сервера'},
          ),
        );

    testWidgets('квота на сутки — без повтора, текст сервера не показан',
        (tester) async {
      parseResult = (_) async => throw serverError(429, 'AI_QUOTA_EXCEEDED');
      await open(tester);
      speech.say('кофе 4 евро', isFinal: true);
      await settle(tester);
      expect(message(tester), startsWith('Лимит голосового ввода'));
      expect(find.byKey(const ValueKey('voice_retry')), findsNothing);
      expect(find.textContaining('текст сервера'), findsNothing);
    });

    testWidgets('ИИ недоступен (503) — с повтором', (tester) async {
      parseResult = (_) async => throw serverError(503, 'SERVICE_UNAVAILABLE');
      await open(tester);
      speech.say('кофе 4 евро', isFinal: true);
      await settle(tester);
      expect(message(tester), startsWith('Не удалось разобрать фразу'));
      expect(find.byKey(const ValueKey('voice_retry')), findsOneWidget);
    });

    testWidgets('нет сети — общий текст ошибки сети', (tester) async {
      parseResult = (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/voice/parse'),
            type: DioExceptionType.connectionError,
          );
      await open(tester);
      speech.say('кофе 4 евро', isFinal: true);
      await settle(tester);
      expect(message(tester), LanguageManager.l10n.err_connection_error);
    });

    testWidgets('«Отмена» — распознавание прервано, результата нет',
        (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('voice_cancel')));
      await settle(tester);
      expect(closed, isTrue);
      expect(result, isNull);
      expect(speech.cancelCalls, 1);
    });
  });

  group('Сценарий голосового ввода', () {
    Future<void> start(
      WidgetTester tester, {
      bool signedIn = true,
      List<Transaction>? drafts,
    }) async {
      await tester.pumpWidget(host((context) => VoiceInputFlow.start(
            context,
            signedIn: signedIn,
            parse: (_) async => drafts ?? const [],
          )));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('гость — тост «после входа», шторка не открывается',
        (tester) async {
      await start(tester, signedIn: false);
      expect(find.text('Голосовой ввод доступен после входа в аккаунт'),
          findsOneWidget);
      expect(find.byType(VoiceListeningSheet), findsNothing);
      expect(speech.listenCalls, 0);
    });

    testWidgets('одна запись — обычная форма «Новая запись», уже заполнена',
        (tester) async {
      await start(tester, drafts: [draft(1, 'Кофе', 4.5)]);
      speech.say('кофе четыре с половиной евро', isFinal: true);
      await settle(tester);

      expect(find.text('Новая запись'), findsOneWidget);
      expect(find.widgetWithText(TextField, '4,50'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Кофе'), findsOneWidget);
      expect(LocalDbService.instance.getAllTransactions(), isEmpty);

      await tester.tap(find.byKey(const ValueKey('add_transaction_submit')));
      await settle(tester);
      final saved = LocalDbService.instance.getAllTransactions().single;
      expect(saved.amount, 4.5);
      expect(saved.description, 'Кофе');
      expect(saved.category, Category.food);
    });

    testWidgets('несколько — список по дням: правка, удаление, «Сохранить все»',
        (tester) async {
      await start(tester, drafts: [
        draft(1, 'Кофе', 4),
        draft(2, 'Такси', 12,
            date: yesterday.add(const Duration(hours: 9)),
            category: Category.transport),
      ]);
      speech.say('кофе 4 евро и такси 12 вчера', isFinal: true);
      await settle(tester);

      expect(find.text('Распознано 2 записи'), findsOneWidget);
      expect(find.text('«кофе 4 евро и такси 12 вчера»'), findsOneWidget);
      expect(find.text('Сохранить все (2)'), findsOneWidget);
      expect(find.textContaining('Сегодня'), findsOneWidget);

      // Правка черновика: форма без сохранения, кнопка «Готово»
      await tester.tap(find.text('Такси'));
      await settle(tester);
      expect(find.text('Редактировать запись'), findsOneWidget);
      expect(find.text('Готово'), findsOneWidget);
      expect(find.byKey(const ValueKey('recurrence_toggle')), findsNothing);
      await tester.enterText(
          find.descendant(
              of: find.byType(TransactionAmountField),
              matching: find.byType(TextField)),
          '15');
      await tester.tap(find.byKey(const ValueKey('add_transaction_submit')));
      await settle(tester);
      expect(LocalDbService.instance.getAllTransactions(), isEmpty);
      expect(find.text('Распознано 2 записи'), findsOneWidget);

      // Свайп убирает черновик из списка
      await tester.drag(find.text('Кофе'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Распознана 1 запись'), findsOneWidget);
      expect(find.text('Кофе'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('voice_save_all')));
      await settle(tester);
      final saved = LocalDbService.instance.getAllTransactions().single;
      expect(saved.description, 'Такси');
      expect(saved.amount, 15);
      expect(saved.category, Category.transport);
      expect(DateUtils.dateOnly(saved.date), yesterday);
      expect(find.byType(VoiceDraftsSheet), findsNothing);
    });

    testWidgets('убрали все черновики — список закрывается', (tester) async {
      await start(tester, drafts: [draft(1, 'Кофе', 4), draft(2, 'Чай', 3)]);
      speech.say('кофе и чай', isFinal: true);
      await settle(tester);
      await tester.drag(find.text('Кофе'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Чай'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceDraftsSheet), findsNothing);
      expect(LocalDbService.instance.getAllTransactions(), isEmpty);
    });

    testWidgets('успешный ввод отключает подсказку про «+»', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await start(tester, drafts: [draft(1, 'Кофе', 4)]);
      speech.say('кофе 4 евро', isFinal: true);
      await settle(tester);
      PreferencesService.instance.resetVoiceHintTurn();
      expect(await PreferencesService.instance.takeVoiceHintTurn(), isFalse);
    });
  });

  group('Правка черновика', () {
    testWidgets('возвращает исправленный черновик с тем же localId',
        (tester) async {
      Transaction? edited;
      await tester.pumpWidget(host((context) async {
        edited = await AddTransactionSheet.editDraft(
            context, draft(7, 'Кофе', 4, date: yesterday));
      }));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Кофе'), 'Латте');
      await tester.tap(find.byKey(const ValueKey('add_transaction_submit')));
      await settle(tester);

      expect(edited!.localId, 7);
      expect(edited!.description, 'Латте');
      expect(edited!.amount, 4);
      expect(DateUtils.dateOnly(edited!.date), yesterday);
      expect(LocalDbService.instance.getAllTransactions(), isEmpty);
    });
  });

  group('Кнопка «+»', () {
    testWidgets('долгое нажатие — голосовой ввод, тап — как раньше',
        (tester) async {
      var taps = 0;
      var longPresses = 0;
      await tester.pumpWidget(app(Scaffold(
        body: Center(
          child: LiquidGlassFab(
            onPressed: () => taps++,
            onLongPress: () => longPresses++,
            longPressHint: 'надиктовать запись',
          ),
        ),
      )));
      await tester.longPress(find.byType(LiquidGlassFab));
      await tester.pump();
      expect(longPresses, 1);
      expect(taps, 0);
      // Подсказка-tooltip открывалась бы тем же долгим нажатием
      expect(find.byType(Tooltip), findsNothing);

      await tester.tap(find.byType(LiquidGlassFab));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('без долгого нажатия — подсказка-tooltip как раньше',
        (tester) async {
      await tester.pumpWidget(app(Scaffold(
        body: Center(child: LiquidGlassFab(onPressed: () {})),
      )));
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });
}
