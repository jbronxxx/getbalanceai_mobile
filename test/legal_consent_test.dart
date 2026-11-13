import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/auth_screen.dart';
import 'package:getbalanceai_mobile/screens/legal_consent_gate.dart';
import 'package:getbalanceai_mobile/screens/terms_update_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LEG-01: явное принятие соглашения и политики — отметка на экране входа,
/// экран новой версии соглашения, шторка о новой политике.

const _version = '2026-11-13';

Map<String, dynamic> _legal({
  bool terms = true,
  bool privacy = true,
}) =>
    {
      'terms_version': _version,
      'terms_accepted': terms,
      'privacy_version': _version,
      'privacy_accepted': privacy,
    };

Map<String, dynamic> _user({bool terms = true, bool privacy = true}) => {
      'id': '11111111-1111-1111-1111-111111111111',
      'email': 'user@example.com',
      'name': 'User',
      'avatar_url': null,
      'base_currency': 'EUR',
      'created_at': '2026-11-13T10:00:00Z',
      'legal': _legal(terms: terms, privacy: privacy),
    };

Map<String, dynamic> _versions() => {
      'terms': {
        'version': _version,
        'effective_date': _version,
        'changes': ['Пункт соглашения'],
      },
      'privacy': {
        'version': _version,
        'effective_date': _version,
        'changes': ['Пункт политики'],
      },
    };

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _success(Object data) =>
    _json({'status': 'success', 'data': data});

ResponseBody _error(String code, int status) =>
    _json({'status': 'error', 'code': code, 'message': 'x'}, status);

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

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigator}) => MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    EnvironmentConfig.setCurrentForTesting(Environment.local);
  });

  tearDown(() {
    EnvironmentConfig.setCurrentForTesting(Environment.prod);
  });

  group('Модели', () {
    test('Профиль разбирает статус документов', () {
      final profile =
          AuthMeResponseModel.fromJson({'data': _user(terms: false)});
      expect(profile.legal?.termsAccepted, isFalse);
      expect(profile.legal?.privacyVersion, _version);
    });

    test('Профиль без legal — статус неизвестен', () {
      final user = _user()..remove('legal');
      expect(AuthMeResponseModel.fromJson({'data': user}).legal, isNull);
    });

    test('Версии с датой и пунктами', () {
      final versions = LegalVersions.fromJson(_versions());
      expect(versions.terms.effectiveDate, DateTime(2026, 11, 13));
      expect(versions.privacy.changes, ['Пункт политики']);
    });
  });

  group('LegalApiService', () {
    late List<RequestOptions> requests;
    late LegalApiService service;

    setUp(() {
      requests = [];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _Adapter((options) async {
        requests.add(options);
        if (options.path == '/legal') return _success(_versions());
        return _success(_user());
      });
      service = LegalApiService(
        dio: dio,
        authOptions: ([token]) =>
            Options(headers: {'Authorization': 'Bearer t'}),
      );
    });

    test('Статус: экран соглашения, уведомление о политике', () {
      expect(service.termsRequired, isFalse);
      expect(service.privacyNoticePending, isFalse);

      service.update(LegalStatus.fromJson(_legal(privacy: false)));
      expect(service.termsRequired, isFalse);
      expect(service.privacyNoticePending, isTrue);

      service
          .update(LegalStatus.fromJson(_legal(terms: false, privacy: false)));
      expect(service.termsRequired, isTrue);
      expect(service.privacyNoticePending, isFalse);
    });

    test('403 без версий: соглашение не принято, известный статус не трогаем',
        () {
      service.markTermsRequired();
      expect(service.status.value, LegalStatus.termsRequired);

      final known = LegalStatus.fromJson(_legal(terms: false, privacy: false));
      service.update(known);
      service.markTermsRequired();
      expect(service.status.value, known);
    });

    test('accept отправляет показанные версии и обновляет статус', () async {
      service.update(LegalStatus.fromJson(_legal(terms: false)));
      await service.accept(termsVersion: _version);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/legal/accept');
      expect(request.data, {'terms_version': _version});
      expect(service.termsRequired, isFalse);
    });

    test('Версии запрашиваются на языке интерфейса', () async {
      final versions = await service.fetchVersions('en');
      expect(requests.single.queryParameters, {'lang': 'en'});
      expect(versions.terms.version, _version);
    });
  });

  group('Вход и профиль', () {
    late List<RequestOptions> requests;
    late AuthApiService auth;
    LegalStatus? reported;

    setUp(() {
      requests = [];
      reported = null;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _Adapter((options) async {
        requests.add(options);
        if (options.path == '/auth/me') return _success(_user(terms: false));
        return _success({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'user': _user(),
        });
      });
      auth = AuthApiService(
        dio: dio,
        storage: const FlutterSecureStorage(),
        onLegalStatus: (status) => reported = status,
      );
    });

    tearDown(() => auth.dispose());

    test('Вход через Google и Apple отправляет accept_legal', () async {
      await auth.loginWithGoogle('google-token');
      await auth.loginWithApple('apple-token');

      final bodies = requests
          .where((r) => r.path.startsWith('/auth/'))
          .map((r) => r.data as Map)
          .toList();
      expect(bodies.map((b) => b['accept_legal']), [true, true]);
      expect(reported?.termsAccepted, isTrue);
    });

    test('refreshProfile передаёт статус из GET /auth/me', () async {
      await auth.setTokens('access', 'refresh');
      await auth.refreshProfile();
      expect(requests.single.path, '/auth/me');
      expect(reported?.termsAccepted, isFalse);
    });

    test('refreshProfile без сессии не ходит в сеть', () async {
      await auth.refreshProfile();
      expect(requests, isEmpty);
    });

    test('Выход сбрасывает статус', () async {
      await auth.setTokens('access', 'refresh');
      await auth.refreshProfile();
      await auth.clearAllUserData();
      expect(reported, isNull);
    });
  });

  group('ApiService: 403 TERMS_NOT_ACCEPTED', () {
    late HttpClientAdapter original;

    setUp(() {
      original = ApiService.instance.dio.httpClientAdapter;
      ApiService.instance.legal.update(null);
    });

    tearDown(() {
      ApiService.instance.dio.httpClientAdapter = original;
      ApiService.instance.legal.update(null);
    });

    test('Ответ с кодом открывает экран новой версии', () async {
      ApiService.instance.dio.httpClientAdapter =
          _Adapter((_) async => _error('TERMS_NOT_ACCEPTED', 403));
      await expectLater(
          ApiService.instance.dio.get('/transactions/'), throwsA(anything));
      expect(ApiService.instance.legal.termsRequired, isTrue);
    });

    test('Другой 403 статус не меняет', () async {
      ApiService.instance.dio.httpClientAdapter =
          _Adapter((_) async => _error('FORBIDDEN', 403));
      await expectLater(
          ApiService.instance.dio.get('/transactions/'), throwsA(anything));
      expect(ApiService.instance.legal.status.value, isNull);
    });
  });

  group('Экран входа', () {
    Finder googleTapTarget() => find.ancestor(
          of: find.text(LanguageManager.l10n.login_with_google),
          matching: find.byType(InkWell),
        );

    testWidgets('Кнопка входа неактивна, пока не отмечено принятие',
        (tester) async {
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.pumpAndSettle();

      final checkbox = find.byKey(const ValueKey('legal_consent_checkbox'));
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      expect(tester.widget<InkWell>(googleTapTarget()).onTap, isNull);

      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      expect(tester.widget<InkWell>(googleTapTarget()).onTap, isNotNull);

      // Тап по тексту рядом с галочкой снимает отметку
      final label = find.textContaining('Принимаю', findRichText: true);
      await tester.tapAt(tester.getTopLeft(label) + const Offset(8, 8));
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    });
  });

  group('Экран новой версии соглашения', () {
    late HttpClientAdapter original;
    late List<RequestOptions> requests;
    late Future<ResponseBody> Function(RequestOptions options) respond;

    setUp(() async {
      requests = [];
      original = ApiService.instance.dio.httpClientAdapter;
      respond = (options) async {
        switch (options.path) {
          case '/legal':
            return _success(_versions());
          case '/auth/me':
            return _success(_user(terms: false, privacy: false));
          case '/legal/accept':
            return _success(_user());
        }
        return _error('NOT_FOUND', 404);
      };
      ApiService.instance.dio.httpClientAdapter = _Adapter((options) {
        requests.add(options);
        return respond(options);
      });
      await ApiService.instance.auth.setTokens('access', 'refresh');
    });

    tearDown(() async {
      ApiService.instance.dio.httpClientAdapter = original;
      await ApiService.instance.auth.clearAllUserData();
    });

    Future<GlobalKey<NavigatorState>> openGate(WidgetTester tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(
        LegalConsentGate(
          navigator: navigator,
          child: const Scaffold(body: Text('Баланс')),
        ),
        navigator: navigator,
      ));
      ApiService.instance.legal.markTermsRequired();
      await tester.pumpAndSettle();
      return navigator;
    }

    testWidgets('Показывает изменения обоих документов и принимает обе версии',
        (tester) async {
      await openGate(tester);

      expect(find.byType(TermsUpdateScreen), findsOneWidget);
      expect(find.text('Пункт соглашения'), findsOneWidget);
      // Политика тоже не принята — её пункты вторым блоком
      expect(find.text('Пункт политики'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('terms_accept_button')));
      await tester.pumpAndSettle();

      final accept = requests.firstWhere((r) => r.path == '/legal/accept');
      expect(accept.data,
          {'terms_version': _version, 'privacy_version': _version});
      expect(find.byType(TermsUpdateScreen), findsNothing);
      expect(find.text('Баланс'), findsOneWidget);
    });

    testWidgets('Жест «назад» экран не закрывает', (tester) async {
      final navigator = await openGate(tester);
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(TermsUpdateScreen), findsOneWidget);
    });

    testWidgets('Устаревшая версия — сообщение и новые версии', (tester) async {
      await openGate(tester);
      final base = respond;
      respond = (options) => options.path == '/legal/accept'
          ? Future.value(_error('LEGAL_VERSION_OUTDATED', 409))
          : base(options);

      await tester.tap(find.byKey(const ValueKey('terms_accept_button')));
      await tester.pumpAndSettle();

      expect(find.byType(TermsUpdateScreen), findsOneWidget);
      expect(find.text(LanguageManager.l10n.legal_version_outdated),
          findsOneWidget);
      expect(requests.where((r) => r.path == '/legal').length, 2);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Без сети — сообщение и повтор', (tester) async {
      final base = respond;
      respond = (options) async {
        if (options.path == '/legal') {
          throw DioException.connectionError(
              requestOptions: options, reason: 'offline');
        }
        return base(options);
      };
      await openGate(tester);

      expect(find.text(LanguageManager.l10n.legal_load_error), findsOneWidget);
      respond = base;
      await tester.tap(find.byKey(const ValueKey('terms_retry_button')));
      await tester.pumpAndSettle();
      expect(find.text('Пункт соглашения'), findsOneWidget);
    });

    testWidgets('Выход из аккаунта закрывает экран', (tester) async {
      await openGate(tester);
      await ApiService.instance.auth.clearAllUserData();
      await tester.pumpAndSettle();
      expect(find.byType(TermsUpdateScreen), findsNothing);
    });
  });

  group('Шторка о новой политике', () {
    testWidgets('Один раз за версию; «Понятно» отмечает ознакомление',
        (tester) async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _Adapter((options) async {
        requests.add(options);
        if (options.path == '/legal') return _success(_versions());
        return _success(_user());
      });
      final service = LegalApiService(
        dio: dio,
        authOptions: ([token]) => Options(),
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(
        LegalConsentGate(
          service: service,
          navigator: navigator,
          child: const Scaffold(body: Text('Баланс')),
        ),
        navigator: navigator,
      ));

      service.update(LegalStatus.fromJson(_legal(privacy: false)));
      // Версии приходят из сети после кадра: несколько кадров до шторки
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(
          find.text(LanguageManager.l10n.privacy_update_title), findsOneWidget);
      expect(find.text('Пункт политики'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('privacy_update_ok_button')));
      await tester.pumpAndSettle();
      final accept = requests.firstWhere((r) => r.path == '/legal/accept');
      expect(accept.data, {'privacy_version': _version});
      expect(service.privacyNoticePending, isFalse);
      expect(
          find.text(LanguageManager.l10n.privacy_update_title), findsNothing);
    });
  });
}
