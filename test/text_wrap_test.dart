import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/cubits/auth/auth_cubit.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/screens/auth_screen.dart';
import 'package:getbalanceai_mobile/screens/main_shell.dart';
import 'package:getbalanceai_mobile/screens/service_unavailable_screen.dart';
import 'package:getbalanceai_mobile/screens/startup_error_screen.dart';
import 'package:getbalanceai_mobile/screens/transaction_search_screen.dart';
import 'package:getbalanceai_mobile/screens/welcome_setup_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/insights/report_export_sheet.dart';
import 'package:getbalanceai_mobile/widgets/period/period.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Переносы текста на всех экранах (UX-08): ни одно слово не рвётся посреди
/// («Редактиров / ать») на телефоне 360 dp при обычном и крупном (×1.3)
/// шрифте на всех языках, а подписи кнопок [OneLineLabel] при обычном
/// шрифте не уменьшаются. Текст меряется настоящим шрифтом приложения
/// (Inter из assets): тестовый шрифт с квадратными глифами вдвое шире и дал
/// бы ложные срабатывания.

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

/// Буква, цифра или апостроф внутри слова («O'chirish»).
final _wordChar = RegExp(r"[\p{L}\p{N}'ʻ’]", unicode: true);

/// Места, где перенос строки пришёлся внутрь слова: соседние символы слова
/// оказались на разных строках.
List<String> _brokenWords(RenderParagraph p) {
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  if (text.length < 2) return const [];
  final lineOf = List<double?>.filled(text.length, null);
  for (var i = 0; i < text.length; i++) {
    final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1));
    if (boxes.isNotEmpty) lineOf[i] = boxes.first.top;
  }
  final result = <String>[];
  for (var i = 1; i < text.length; i++) {
    final a = lineOf[i - 1], b = lineOf[i];
    if (a == null || b == null || b <= a + 1) continue;
    if (!_wordChar.hasMatch(text[i - 1]) || !_wordChar.hasMatch(text[i])) {
      continue;
    }
    var start = i - 1, end = i;
    while (start > 0 && _wordChar.hasMatch(text[start - 1])) {
      start--;
    }
    while (end < text.length - 1 && _wordChar.hasMatch(text[end + 1])) {
      end++;
    }
    result.add('${text.substring(start, i)} / ${text.substring(i, end + 1)}');
  }
  return result;
}

/// Суммы из [amounts], уменьшенные `FittedBox`, — с шириной «стало из
/// было».
List<String> _shrunkAmounts(WidgetTester tester, List<String> amounts) => [
      for (final amount in amounts)
        for (final fitted in find
            .ancestor(of: find.text(amount), matching: find.byType(FittedBox))
            .evaluate())
          if ((fitted.findRenderObject()! as RenderBox).size.width <
              tester
                      .renderObject<RenderParagraph>(find.text(amount))
                      .size
                      .width -
                  0.5)
            '«$amount» уменьшена',
    ];

/// Регистрирует Inter из assets под именами, которые даёт google_fonts
/// (`Inter_regular`, `Inter_500`…), — как на устройстве.
Future<void> _loadAppFonts() async {
  Future<ByteData> file(String name) async => ByteData.sublistView(
      await File('assets/google_fonts/Inter-$name.ttf').readAsBytes());
  const variants = {
    'regular': 'Regular',
    '500': 'Medium',
    '600': 'SemiBold',
    '700': 'Bold',
    '800': 'Bold',
    '900': 'Bold',
  };
  for (final MapEntry(:key, :value) in variants.entries) {
    await (FontLoader('Inter_$key')..addFont(file(value))).load();
  }
}

class _HttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        '{"status":"success","data":{"insights":[],"generated_at":null}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthCubit authCubit;
  late Transaction foreign;
  late Transaction rejected;
  late Budget budget;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'language_code': 'ru',
      'onboarding_setup_completed': true,
    });
    PackageInfo.setMockInitialValues(
      appName: 'GetBalance',
      packageName: 'com.getbalanceai.mobile',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final tempDir = await Directory.systemTemp.createTemp('text_wrap_test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
    LanguageManager.initFallback();
    await CurrencyFormatter.setCurrency(Currency.usd);
    await _loadAppFonts();
    await LocalDbService.init();
    ApiService.instance.dio.httpClientAdapter = _HttpAdapter();
    await ApiService.instance.auth.setTokens('token', 'refresh');

    final db = LocalDbService.instance;
    final now = DateTime.now();
    Transaction tx(String description, Category category,
            {TransactionType type = TransactionType.expense,
            String currency = 'USD',
            double amount = 1250,
            int daysAgo = 0}) =>
        Transaction(
          amount: amount,
          description: description,
          dbCategory: category.name,
          dbType: type.name,
          dateMilliseconds:
              now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch,
          dateCreatedMilliseconds: now.millisecondsSinceEpoch,
          currencyCode: currency,
          baseAmount: currency == 'USD' ? amount : 0,
        );
    db.saveTransaction(tx('Кофе', Category.food));
    db.saveTransaction(
        tx('Зарплата', Category.salary, type: TransactionType.income));
    db.saveTransaction(tx('Подписка', Category.subscriptions,
        currency: 'EUR', amount: 12.99, daysAgo: 1));
    db.saveTransaction(tx('Обед', Category.food, currency: 'KZT', daysAgo: 2));
    for (final c in Category.expenseCategories) {
      db.saveTransaction(tx('', c, amount: 300, daysAgo: 3));
    }
    foreign =
        db.getAllTransactions().firstWhere((t) => t.description == 'Подписка');
    // Сумма в сотни миллионов сумов рядом с датой и описанием
    rejected = tx('Кофе', Category.food, currency: 'UZS', amount: 350000000)
      ..syncRejectCode = 'INVALID_CURRENCY';
    budget = Budget(
      dbCategory: Category.food.name,
      limitAmount: 500,
      currencyCode: 'USD',
      month: now.month,
      year: now.year,
      spent: 0,
      remaining: 500,
    );
    db.saveBudget(budget);
    db.saveBudget(Budget(
      dbCategory: Category.entertainment.name,
      limitAmount: 50,
      currencyCode: 'EUR',
      month: now.month,
      year: now.year,
      spent: 0,
      remaining: 50,
    ));
  });

  setUp(() {
    authCubit = _MockAuthCubit();
    when(() => authCubit.state)
        .thenReturn(Authenticated(email: 'user@example.com', name: 'Евгений'));
    when(() => authCubit.stream).thenAnswer((_) => const Stream.empty());
  });

  /// Конфигурации: язык × масштаб шрифта на телефоне 360 dp (на более
  /// широких экранах места только больше).
  final configs = [
    for (final language in AppLanguage.values)
      for (final scale in [1.0, 1.3]) (language, 360.0, scale),
  ];

  /// Проверяет поверхность [surface] во всех конфигурациях: падает со
  /// списком разорванных слов. [build] — что
  /// показать; [open] — действия после первого кадра (открыть шторку,
  /// переключить вкладку).
  void audit(
    String surface,
    Widget Function() build, {
    Future<void> Function(WidgetTester tester)? open,
    bool guest = false,
  }) {
    testWidgets(surface, (tester) async {
      final broken = <String>[];
      if (guest) {
        await tester
            .runAsync(() => ApiService.instance.auth.setTokens(null, null));
        when(() => authCubit.state).thenReturn(Unauthenticated());
      }
      for (final (language, width, scale) in configs) {
        LanguageManager.setLanguage(language, save: false);
        tester.view
          ..physicalSize = Size(width, 840)
          ..devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language.name),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: BlocProvider<AuthCubit>.value(
            value: authCubit,
            child: Builder(builder: (_) => build()),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        if (open != null) await open(tester);
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();

        final config = '${language.name} ${width.toInt()}dp ×$scale';
        for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
          if (!p.hasSize || !p.attached) continue;
          final text = p.text.toPlainText(includeSemanticsLabels: false);
          for (final word in _brokenWords(p)) {
            broken.add('$config: «$word» в «$text»');
          }
          if (scale == 1.0 && p.didExceedMaxLines) {
            broken.add('$config: «$text» обрезан');
          }
        }
        if (scale == 1.0) {
          for (final label in find.byType(OneLineLabel).evaluate()) {
            final fitted = label.findRenderObject()! as RenderBox;
            final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(
                    of: find.byWidget(label.widget),
                    matching: find.byType(RichText)));
            if (fitted.size.width < paragraph.size.width - 0.5) {
              broken.add('$config: «${(label.widget as OneLineLabel).text}» '
                  'уменьшена: ${fitted.size.width.toStringAsFixed(1)} из '
                  '${paragraph.size.width.toStringAsFixed(1)}');
            }
          }
        }
      }
      // Закрыть таймеры тостов и диалогов
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      tester.view.reset();
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      if (guest) {
        await tester.runAsync(
            () => ApiService.instance.auth.setTokens('token', 'refresh'));
      }
      expect(broken.toSet(), isEmpty);
    });
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Открывает виджет шторкой поверх пустого экрана.
  Widget sheetHost(Widget Function() sheet) => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.transparent,
                builder: (_) => sheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

  /// Экран с кнопкой, по которой вызывается [action] (диалог, тост).
  Widget actionHost(void Function(BuildContext context) action) => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => action(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<void> tapOpen(WidgetTester tester) => tapText(tester, 'open');

  group('Вкладки', () {
    audit('Баланс', () => const MainShell());
    audit('Баланс по категориям', () => const MainShell(),
        open: (tester) async {
      await tester.tap(find.byKey(const ValueKey('view_mode_categories')));
      await tester.pump(const Duration(seconds: 1));
    });
    audit('Бюджет', () => const MainShell(),
        open: (tester) => tapText(tester, LanguageManager.l10n.finances));
    audit('Бюджет: пустой месяц с копированием', () => const MainShell(),
        open: (tester) async {
      await tapText(tester, LanguageManager.l10n.finances);
      SelectedPeriodService.instance
          .select(SelectedPeriodService.instance.period.next);
      await tester.pump(const Duration(seconds: 1));
      SelectedPeriodService.instance.reset();
    });
    audit('Аналитика', () => const MainShell(),
        open: (tester) => tapText(tester, LanguageManager.l10n.insights));
    audit('Профиль', () => const MainShell(),
        open: (tester) => tapText(tester, LanguageManager.l10n.profile));
    audit('Гость: Баланс', () => const MainShell(), guest: true);
    audit('Гость: Аналитика', () => const MainShell(),
        guest: true,
        open: (tester) => tapText(tester, LanguageManager.l10n.insights));
    audit('Гость: Профиль', () => const MainShell(),
        guest: true,
        open: (tester) => tapText(tester, LanguageManager.l10n.profile));
  });

  group('Экраны', () {
    audit('Поиск', () => const TransactionSearchScreen());
    audit('Вход', () => const AuthScreen());
    audit('Первая настройка', () => const WelcomeSetupScreen());
    audit('Сервис недоступен', () => const ServiceUnavailableScreen());
    audit(
        'Ошибка запуска', () => StartupErrorScreen(onRetry: () async => true));
  });

  group('UX-12: карточка лимита с суммами в сотни миллионов сумов', () {
    final uzs = Budget(
      dbCategory: Category.entertainment.name,
      limitAmount: 999999999,
      currencyCode: 'UZS',
      month: 11,
      year: 2026,
      spent: 0,
      remaining: 999999999,
    );

    /// Переносы строки только на обычных пробелах (между двумя суммами),
    /// не на неразрывных внутри суммы.
    List<String> badBreaks(RenderParagraph p) {
      final text = p.text.toPlainText(includeSemanticsLabels: false);
      final result = <String>[];
      double? prevTop;
      for (var i = 0; i < text.length; i++) {
        final boxes = p.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1));
        if (boxes.isEmpty) continue;
        final top = boxes.first.top;
        if (prevTop != null && top > prevTop + 1 && text[i - 1] != ' ') {
          result.add('«${text.substring(0, i)} / ${text.substring(i)}»');
        }
        prevTop = top;
      }
      return result;
    }

    for (final spent in [950000000.0, 1250000000.0]) {
      testWidgets('потрачено $spent', (tester) async {
        final problems = <String>[];
        for (final language in AppLanguage.values) {
          for (final scale in [1.0, 1.3]) {
            LanguageManager.setLanguage(language, save: false);
            tester.view
              ..physicalSize = const Size(360, 640)
              ..devicePixelRatio = 1;
            await tester.pumpWidget(MaterialApp(
              locale: Locale(language.name),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BudgetItemCard(
                    budget: uzs,
                    currentSpent: spent,
                    isFirst: false,
                    showSwipeHint: false,
                    onTap: () {},
                    onDelete: () {},
                    onHintShown: () {},
                  ),
                ),
              ),
            ));
            final l10n = LanguageManager.l10n;
            String nbsp(String s) => s.replaceAll(' ', '\u00A0');
            final line = l10n.budget_spent_of(
              nbsp(CurrencyFormatter.format(spent,
                  showSymbol: false, currency: Currency.uzs)),
              nbsp(CurrencyFormatter.format(999999999, currency: Currency.uzs)),
            );
            final p = tester.renderObject<RenderParagraph>(find.text(line));
            final config = '${language.name} ×$scale';
            if (p.didExceedMaxLines) problems.add('$config: обрезано «$line»');
            if (scale == 1.0) {
              final left = CurrencyFormatter.format((999999999 - spent).abs(),
                      currency: Currency.uzs)
                  .replaceAll('-', CurrencyFormatter.typographicMinus);
              for (final s in _shrunkAmounts(tester, [left])) {
                problems.add('$config: $s');
              }
            }
            for (final b in badBreaks(p)) {
              problems.add('$config: перенос внутри суммы $b');
            }
            expect(tester.takeException(), isNull, reason: config);
          }
        }
        tester.view.reset();
        LanguageManager.setLanguage(AppLanguage.ru, save: false);
        expect(problems, isEmpty);
      });
    }
  });

  group('UX-14: заголовок группы «По категориям» с суммами в сотни миллионов',
      () {
    for (final category in [
      Category.entertainment,
      Category.subscriptions,
      Category.shopping,
    ]) {
      testWidgets(category.name, (tester) async {
        final problems = <String>[];
        await CurrencyFormatter.setCurrency(Currency.uzs);
        final transactions = [
          for (var i = 0; i < 3; i++)
            Transaction(
              amount: 250000000,
              description: '',
              dbCategory: category.name,
              dbType: TransactionType.expense.name,
              dateMilliseconds:
                  DateTime(2026, 11, i + 1).millisecondsSinceEpoch,
              dateCreatedMilliseconds: 0,
              currencyCode: 'UZS',
              baseAmount: 250000000,
            ),
        ];
        final summary =
            CategoryMonthSummary.fromTransactions(transactions).single;
        for (final language in AppLanguage.values) {
          for (final scale in [1.0, 1.3]) {
            LanguageManager.setLanguage(language, save: false);
            tester.view
              ..physicalSize = const Size(360, 640)
              ..devicePixelRatio = 1;
            await tester.pumpWidget(MaterialApp(
              locale: Locale(language.name),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CategoryMonthGroup(
                    summary: summary,
                    onTransactionTap: (_) {},
                    onTransactionDelete: (_) {},
                  ),
                ),
              ),
            ));
            final config = '${language.name} ×$scale';
            final name = category.getLocalizedName();
            final nameParagraph =
                tester.renderObject<RenderParagraph>(find.text(name));
            if (scale == 1.0 && nameParagraph.didExceedMaxLines) {
              problems.add('$config: «$name» обрезано');
            }
            for (final p
                in tester.allRenderObjects.whereType<RenderParagraph>()) {
              for (final word in _brokenWords(p)) {
                problems.add('$config: «$word»');
              }
            }
            if (scale == 1.0) {
              final amount = find.byType(FittedBox);
              for (final fitted in amount.evaluate()) {
                final box = fitted.findRenderObject()! as RenderBox;
                final text = tester.renderObject<RenderParagraph>(
                    find.descendant(
                        of: find.byWidget(fitted.widget),
                        matching: find.byType(RichText)));
                if (box.size.width < text.size.width - 0.5) {
                  problems.add('$config: сумма уменьшена '
                      '${box.size.width.toStringAsFixed(1)} из '
                      '${text.size.width.toStringAsFixed(1)}');
                }
              }
            }
            expect(tester.takeException(), isNull, reason: config);
          }
        }
        tester.view.reset();
        LanguageManager.setLanguage(AppLanguage.ru, save: false);
        await CurrencyFormatter.setCurrency(Currency.usd);
        expect(problems, isEmpty);
      });
    }
  });

  group('Шторки', () {
    audit('Новая запись', () => sheetHost(() => const AddTransactionSheet()),
        open: tapOpen);
    audit('Правка записи в валюте',
        () => sheetHost(() => AddTransactionSheet(transactionToEdit: foreign)),
        open: tapOpen);
    audit(
        'Новый лимит',
        () => sheetHost(() => AddBudgetSheet(
            selectedMonth: budget.month,
            selectedYear: budget.year,
            onSaved: () {})),
        open: tapOpen);
    audit(
        'Правка лимита',
        () => sheetHost(() => AddBudgetSheet(
              selectedMonth: budget.month,
              selectedYear: budget.year,
              budgetToEdit: budget,
              onSaved: () {},
              onDelete: () {},
            )),
        open: tapOpen);
    audit('Карточка операции в валюте',
        () => sheetHost(() => TransactionDetailsSheet(transaction: foreign)),
        open: tapOpen);
    audit(
        'Все категории',
        () => sheetHost(() => const CategoryPickerSheet(
            categories: Category.expenseCategories, selected: Category.food)),
        open: tapOpen);
    audit('Валюта', () => sheetHost(() => const CurrencyPickerSheet()),
        open: tapOpen);
    audit('Язык', () => sheetHost(() => const LanguagePickerSheet()),
        open: tapOpen);
    audit('Тема', () => sheetHost(() => const ThemeModePickerSheet()),
        open: tapOpen);
    audit('Выбор месяца', () => sheetHost(() => const PeriodPickerSheet()),
        open: tapOpen);
    audit('Выгрузка отчёта', () => sheetHost(() => const ReportExportSheet()),
        open: tapOpen);
    audit('Отклонённые записи',
        () => sheetHost(() => SyncRejectedSheet(transactions: [rejected])),
        open: tapOpen);
  });

  group('Диалоги и тосты', () {
    audit(
        'Выход',
        () => actionHost((context) => AppAlerts.showConfirmDialog(
              context,
              title: context.l10n.logout_confirm_title,
              message: context.l10n.logout_unsynced_warning(3),
              confirmText: context.l10n.logout,
              cancelText: context.l10n.cancel,
              isDestructive: true,
              icon: Icons.logout_rounded,
            )),
        open: tapOpen);
    audit(
        'Удаление аккаунта',
        () => actionHost((context) => AppAlerts.showConfirmDialog(
              context,
              title: context.l10n.delete_account_title,
              message: context.l10n.delete_account_confirm,
              confirmText: context.l10n.delete_account_confirm_btn,
              cancelText: context.l10n.cancel,
              isDestructive: true,
              icon: Icons.delete_forever_rounded,
            )),
        open: tapOpen);
    audit(
        'Сервис недоступен (диалог)',
        () => actionHost(
            (context) => AppAlerts.showServiceUnavailableDialog(context)),
        open: tapOpen);
    audit(
        'Слишком много запросов',
        () => actionHost((context) =>
            AppAlerts.showRateLimitDialog(context, retryAfterSeconds: 30)),
        open: tapOpen);
    audit(
        'Ошибка (диалог)',
        () => actionHost((context) => AppAlerts.showErrorDialog(context,
            title: context.l10n.sync_error,
            message: context.l10n.sync_login_required)),
        open: tapOpen);
    audit('Тост «Нет интернета»',
        () => actionHost((context) => AppAlerts.noInternet(context)),
        open: tapOpen);
    audit(
        'Тост с отменой',
        () => actionHost((context) => AppAlerts.showToast(
              context,
              message: context.l10n.transaction_deleted,
              actionLabel: context.l10n.undo_action,
              onAction: () {},
            )),
        open: tapOpen);
  });
}
