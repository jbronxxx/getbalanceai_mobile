import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/account_actions.dart';
import 'package:getbalanceai_mobile/screens/paywall_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockAuthApiService extends Mock implements AuthApiService {}

/// Магазин без RevenueCat: варианты и исходы задаются в тесте.
class _FakeStore implements PurchaseService {
  bool available = true;
  List<ProOption> options = const [
    ProOption(
        period: ProPeriod.month, priceString: '€3,99', price: 3.99, package: 1),
    ProOption(
        period: ProPeriod.year,
        priceString: '€29,99',
        price: 29.99,
        trialDays: 14,
        package: 2),
  ];
  StoreOutcome purchaseOutcome = StoreOutcome.completed;
  StoreOutcome restoreOutcome = StoreOutcome.completed;
  final purchased = <ProPeriod>[];
  var restores = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<void> logIn(String userId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<List<ProOption>> loadOptions() async => options;

  @override
  Future<StoreOutcome> purchase(ProOption option) async {
    purchased.add(option.period);
    return purchaseOutcome;
  }

  @override
  Future<StoreOutcome> restore() async {
    restores++;
    return restoreOutcome;
  }

  @override
  Future<Uri> managementUrl() async =>
      Uri.parse('https://play.google.com/store/account/subscriptions');
}

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

final _resetsAt = DateTime.utc(2026, 11, 15, 19);

Map<String, dynamic> _profile({String plan = 'free', bool willRenew = false}) =>
    {
      'subscription': {
        'plan': plan,
        'expires_at': plan == 'pro' ? '2026-12-14T10:00:00Z' : null,
        'will_renew': willRenew,
        'is_trial': false,
      },
      'limits': [
        {
          'feature': 'ai_report',
          'period': plan == 'pro' ? 'day' : 'month',
          'limit': plan == 'pro' ? 5 : 1,
          'used': 0,
          'remaining': plan == 'pro' ? 5 : 1,
          'resets_at': '2026-11-30T19:00:00Z',
        },
        {
          'feature': 'voice',
          'period': 'day',
          'limit': plan == 'pro' ? 30 : 5,
          'used': 2,
          'remaining': plan == 'pro' ? 28 : 3,
          'resets_at': _resetsAt.toIso8601String(),
        },
        {'feature': 'something_new', 'period': 'day', 'limit': 1},
      ],
    };

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      routes: {'/login': (_) => const Scaffold(body: Text('экран входа'))},
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
  });

  group('Модель тарифа', () {
    test('профиль: тариф, лимиты; неизвестная функция пропускается', () {
      final status = PlanStatus.fromProfile(_profile(plan: 'pro'))!;
      expect(status.isPro, isTrue);
      expect(status.subscription.expiresAt, DateTime.utc(2026, 12, 14, 10));
      expect(status.limits.keys,
          unorderedEquals([PlanFeature.aiReport, PlanFeature.voice]));
      expect(status.limits[PlanFeature.voice]!.remaining, 28);
      expect(status.limits[PlanFeature.aiReport]!.period, LimitPeriod.day);
    });

    test('без subscription (ответ входа) — null; неизвестный тариф — Free', () {
      expect(PlanStatus.fromProfile({'id': 'u'}), isNull);
      expect(SubscriptionStatus.fromJson({'plan': 'family'}).isPro, isFalse);
    });

    test('сохранение и чтение — тот же статус', () {
      final status = PlanStatus.fromProfile(_profile(plan: 'pro'))!;
      final restored = PlanStatus.fromProfile(
          jsonDecode(jsonEncode(status.toJson())) as Map<String, dynamic>)!;
      expect(restored.isPro, isTrue);
      expect(restored.limits[PlanFeature.voice]!.resetsAt, _resetsAt);
    });

    test('окно закончилось — полный остаток и следующий сброс', () {
      final limit = PlanStatus.fromProfile(_profile())!
          .limits[PlanFeature.voice]!
          .exhausted(_resetsAt);
      final before = _resetsAt.subtract(const Duration(minutes: 1));
      expect(limit.isExhaustedAt(before), isTrue);

      final after = limit.at(_resetsAt.add(const Duration(hours: 30)));
      expect(after.remaining, 5);
      expect(after.used, 0);
      expect(after.resetsAt.isAfter(_resetsAt.add(const Duration(hours: 30))),
          isTrue);
      expect(limit.isExhaustedAt(_resetsAt), isFalse);
    });

    test('вызов уменьшает остаток, не ниже нуля', () {
      final limit =
          PlanStatus.fromProfile(_profile())!.limits[PlanFeature.voice]!;
      final now = _resetsAt.subtract(const Duration(hours: 1));
      var current = limit;
      for (var i = 0; i < 5; i++) {
        current = current.consumed(now);
      }
      expect(current.remaining, 0);
      expect(current.used, 7);
    });

    test('403 PLAN_LIMIT_REACHED разбирается, другие ответы — нет', () {
      final reached = PlanLimitReached.fromResponse(403, {
        'code': 'PLAN_LIMIT_REACHED',
        'details': {
          'feature': 'ai_report',
          'plan': 'free',
          'limit': 1,
          'period': 'month',
          'resets_at': '2026-11-30T19:00:00Z',
        },
      })!;
      expect(reached.feature, PlanFeature.aiReport);
      expect(reached.plan, PlanCode.free);
      expect(reached.period, LimitPeriod.month);
      expect(reached.resetsAt, DateTime.utc(2026, 11, 30, 19));

      expect(PlanLimitReached.fromResponse(403, {'code': 'TERMS_NOT_ACCEPTED'}),
          isNull);
      expect(PlanLimitReached.fromResponse(429, {'code': 'PLAN_LIMIT_REACHED'}),
          isNull);
    });
  });

  group('SubscriptionApiService', () {
    late List<RequestOptions> requests;
    late SubscriptionApiService service;
    var now = _resetsAt.subtract(const Duration(hours: 2));

    SubscriptionApiService build() {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.httpClientAdapter = _Adapter((options) async {
        requests.add(options);
        return _json({
          'status': 'success',
          'data': {
            'plan': 'pro',
            'expires_at': '2026-12-14T10:00:00Z',
            'will_renew': true,
            'is_trial': true,
          },
        });
      });
      return SubscriptionApiService(
        dio: dio,
        authOptions: ([String? token]) => Options(),
        now: () => now,
      );
    }

    setUp(() {
      requests = [];
      now = _resetsAt.subtract(const Duration(hours: 2));
      service = build();
    });

    test('статус сохраняется и читается при следующем запуске', () async {
      await service.update(PlanStatus.fromProfile(_profile(plan: 'pro')));
      final next = build();
      await next.init(signedIn: true);
      expect(next.isPro, isTrue);
      expect(next.limit(PlanFeature.voice)?.remaining, 28);
    });

    test('без сессии сохранённый статус стирается', () async {
      await service.update(PlanStatus.fromProfile(_profile(plan: 'pro')));
      await build().init(signedIn: false);
      final next = build();
      await next.init(signedIn: true);
      expect(next.status.value, isNull);
      expect(next.isPro, isFalse);
    });

    test('остаток: успешный вызов, 403 и новое окно', () async {
      await service.update(PlanStatus.fromProfile(_profile()));
      service.recordUse(PlanFeature.voice);
      expect(service.limit(PlanFeature.voice)?.remaining, 2);
      expect(service.isExhausted(PlanFeature.voice), isFalse);

      service.markLimitReached(PlanLimitReached(
          feature: PlanFeature.voice,
          plan: PlanCode.free,
          resetsAt: _resetsAt));
      expect(service.isExhausted(PlanFeature.voice), isTrue);

      now = _resetsAt.add(const Duration(minutes: 1));
      expect(service.isExhausted(PlanFeature.voice), isFalse);
      expect(service.limit(PlanFeature.voice)?.remaining, 5);
    });

    test('refresh: POST /subscriptions/refresh, лимиты сохраняются', () async {
      await service.update(PlanStatus.fromProfile(_profile()));
      final subscription = await service.refresh();
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/subscriptions/refresh');
      expect(subscription.isTrial, isTrue);
      expect(service.isPro, isTrue);
      expect(service.limit(PlanFeature.voice), isNotNull);
    });

    test('ApiService: 403 PLAN_LIMIT_REACHED отмечает исчерпанный лимит',
        () async {
      final api = ApiService.instance;
      await api.auth.setTokens('token', 'refresh');
      await api.subscription.update(PlanStatus.fromProfile(_profile()));
      final original = api.dio.httpClientAdapter;
      final resetsAt = DateTime.now().toUtc().add(const Duration(hours: 5));
      api.dio.httpClientAdapter = _Adapter((_) async => _json({
            'status': 'error',
            'code': 'PLAN_LIMIT_REACHED',
            'details': {
              'feature': 'voice',
              'plan': 'free',
              'limit': 5,
              'period': 'day',
              'resets_at': resetsAt.toIso8601String(),
            },
          }, 403));
      try {
        await expectLater(
          api.parseVoice(text: 'кофе 4', locale: 'ru', currency: Currency.eur),
          throwsA(isA<DioException>()),
        );
        expect(api.subscription.isExhausted(PlanFeature.voice), isTrue);
      } finally {
        api.dio.httpClientAdapter = original;
        await api.clearAllUserData();
      }
      expect(api.subscription.status.value, isNull);
    });
  });

  test('EntitlementService: выгрузка и автоотчёт — только в Pro', () {
    var pro = false;
    final entitlements = EntitlementService(isPro: () => pro);
    expect(entitlements.isEnabled(AppFeature.reportExport), isFalse);
    expect(entitlements.isEnabled(AppFeature.aiInsights), isFalse);
    pro = true;
    expect(entitlements.isEnabled(AppFeature.reportExport), isTrue);
    expect(entitlements.isEnabled(AppFeature.aiInsights), isTrue);
  });

  group('Пейволл', () {
    late _FakeStore store;
    late _MockApiService api;
    late _MockAuthApiService auth;
    late SubscriptionApiService subscription;
    late String refreshedPlan;

    setUp(() {
      store = _FakeStore();
      api = _MockApiService();
      auth = _MockAuthApiService();
      refreshedPlan = 'pro';
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.httpClientAdapter = _Adapter((_) async => _json({
            'status': 'success',
            'data': {'plan': refreshedPlan, 'will_renew': true},
          }));
      subscription = SubscriptionApiService(
          dio: dio, authOptions: ([String? token]) => Options());
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.subscription).thenReturn(subscription);
      when(() => api.auth).thenReturn(auth);
      when(() => auth.refreshProfile()).thenAnswer((_) async {});
    });

    Future<void> open(WidgetTester tester,
        {PaywallTrigger trigger = PaywallTrigger.subscription}) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  PaywallScreen(trigger: trigger, store: store, api: api),
            )),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final buy = find.byKey(const ValueKey('paywall_buy'));

    testWidgets('цены из магазина, год со скидкой и пробным периодом',
        (tester) async {
      await open(tester, trigger: PaywallTrigger.export);
      expect(find.text('Выгрузка отчётов в CSV и PDF доступна в Pro.'),
          findsOneWidget);
      expect(find.text('€3,99 в месяц'), findsOneWidget);
      expect(find.text('€29,99 в год'), findsOneWidget);
      expect(find.text('−37%'), findsOneWidget);
      expect(find.text('14 дней бесплатно'), findsOneWidget);
      expect(find.textContaining('Бесплатно 14 дней, затем €29,99 в год'),
          findsOneWidget);

      // У месяца пробного нет — «Оформить»
      final month = find.byKey(const ValueKey('paywall_period_month'));
      await tester.ensureVisible(month);
      await tester.tap(month);
      await tester.pumpAndSettle();
      expect(find.text('Оформить'), findsOneWidget);
      expect(find.textContaining('€3,99 в месяц. Подписка продлевается'),
          findsOneWidget);
    });

    testWidgets('покупка: статус с сервера, «Pro оформлен», экран закрыт',
        (tester) async {
      await open(tester);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(store.purchased, [ProPeriod.year]);
      expect(subscription.isPro, isTrue);
      verify(() => auth.refreshProfile()).called(1);
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.text('Pro оформлен. Спасибо!'), findsOneWidget);
    });

    testWidgets('сервер ещё не видит покупку — «включится в течение минут»',
        (tester) async {
      refreshedPlan = 'free';
      await open(tester);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.textContaining('Pro включится в течение нескольких минут'),
          findsOneWidget);
    });

    testWidgets('отмена оплаты — экран остаётся, без сообщений',
        (tester) async {
      store.purchaseOutcome = StoreOutcome.cancelled;
      await open(tester);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);
      verifyNever(() => auth.refreshProfile());
    });

    testWidgets('покупка за другим аккаунтом — объяснение', (tester) async {
      store.purchaseOutcome = StoreOutcome.otherAccount;
      await open(tester);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.textContaining('оформлена в другом аккаунте GetBalance'),
          findsOneWidget);
    });

    testWidgets('восстановление без подписки — подсказка про другой аккаунт',
        (tester) async {
      refreshedPlan = 'free';
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('paywall_restore')));
      await tester.pumpAndSettle();
      expect(store.restores, 1);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.textContaining('Активной подписки для этого аккаунта'),
          findsOneWidget);
    });

    testWidgets('цены не загрузились — «Повторить»', (tester) async {
      store.options = const [];
      await open(tester);
      expect(find.byKey(const ValueKey('paywall_prices_unavailable')),
          findsOneWidget);
      expect(buy, findsNothing);
      expect(find.byKey(const ValueKey('paywall_retry')), findsOneWidget);
    });

    testWidgets('гость: без цен и покупки, «Войдите, чтобы оформить Pro»',
        (tester) async {
      when(() => api.isAuthenticated).thenReturn(false);
      await open(tester);
      expect(find.text('€3,99 в месяц'), findsNothing);
      expect(find.byKey(const ValueKey('paywall_restore')), findsNothing);
      await tester.tap(find.text('Войдите, чтобы оформить Pro'));
      await tester.pumpAndSettle();
      expect(find.text('экран входа'), findsOneWidget);
    });

    testWidgets('«Не сейчас» закрывает экран', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('paywall_not_now')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
    });
  });

  group('Профиль → Подписка', () {
    late _MockApiService api;
    late _MockAuthApiService auth;
    late SubscriptionApiService subscription;

    setUp(() {
      api = _MockApiService();
      auth = _MockAuthApiService();
      subscription = SubscriptionApiService(
          dio: Dio(), authOptions: ([String? token]) => Options());
      when(() => api.subscription).thenReturn(subscription);
      when(() => api.auth).thenReturn(auth);
      when(() => auth.refreshProfile()).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, {required bool signedIn}) async {
      await tester.pumpWidget(_app(Scaffold(
        body: ProfileSubscriptionCard(isAuthenticated: signedIn, api: api),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('Free: тариф, остатки, «Оформить Pro» и восстановление',
        (tester) async {
      await subscription.update(PlanStatus.fromProfile(_profile()));
      await pump(tester, signedIn: true);
      verify(() => auth.refreshProfile()).called(1);
      expect(find.text('Бесплатный'), findsOneWidget);
      expect(find.textContaining('ИИ-отчёт: осталось 1 из 1 в этом месяце'),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('subscription_get_pro')), findsOneWidget);
      expect(find.byKey(const ValueKey('subscription_manage')), findsNothing);
      expect(
          find.byKey(const ValueKey('subscription_restore')), findsOneWidget);
    });

    testWidgets('Pro: дата продления и «Управлять в Google Play»',
        (tester) async {
      await subscription.update(
          PlanStatus.fromProfile(_profile(plan: 'pro', willRenew: true)));
      await pump(tester, signedIn: true);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.textContaining('Продлится 14 декабря'), findsOneWidget);
      expect(find.byKey(const ValueKey('subscription_manage')), findsOneWidget);
      expect(find.byKey(const ValueKey('subscription_get_pro')), findsNothing);
    });

    testWidgets(
        'гость: Free без остатков и восстановления, профиль не читается',
        (tester) async {
      await pump(tester, signedIn: false);
      verifyNever(() => auth.refreshProfile());
      expect(find.text('Бесплатный'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('subscription_get_pro')), findsOneWidget);
      expect(find.byKey(const ValueKey('subscription_restore')), findsNothing);
    });
  });

  group('Удаление аккаунта при подписке', () {
    final subscription = ApiService.instance.subscription;
    tearDown(() => subscription.update(null));

    Future<void> tapDelete(WidgetTester tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AccountActions.deleteAccount(context),
            child: const Text('delete'),
          ),
        ),
      )));
      await tester.tap(find.text('delete'));
      await tester.pumpAndSettle();
    }

    final warning = find.text('Подписка Pro активна');
    final confirmTitle = find.text('Удаление аккаунта');

    testWidgets(
        'Pro продлевается — предупреждение, затем обычное подтверждение',
        (tester) async {
      await subscription.update(
          PlanStatus.fromProfile(_profile(plan: 'pro', willRenew: true)));
      await tapDelete(tester);
      expect(warning, findsOneWidget);
      expect(find.text('Открыть Google Play'), findsOneWidget);

      await tester.tap(find.text('Продолжить удаление'));
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
      expect(confirmTitle, findsOneWidget);
    });

    testWidgets('Pro отменён или Free — сразу подтверждение', (tester) async {
      await subscription.update(PlanStatus.fromProfile(_profile(plan: 'pro')));
      await tapDelete(tester);
      expect(warning, findsNothing);
      expect(confirmTitle, findsOneWidget);
    });
  });
}
