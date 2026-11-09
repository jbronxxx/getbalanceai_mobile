import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile.dart';

/// USAB-03: смена имени в «Профиле».
void main() {
  late List<RequestOptions> requests;
  late ResponseBody Function() reply;

  ResponseBody json(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    requests = [];
    reply = () => json(200, {
          'status': 'success',
          'data': {'name': 'Аня'},
        });
  });

  AuthApiService service() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
    dio.httpClientAdapter = _Adapter((options) async {
      requests.add(options);
      return reply();
    });
    return AuthApiService(dio: dio);
  }

  group('AuthApiService.updateUserName', () {
    test('отправляет имя без пробелов по краям и сохраняет ответ сервера',
        () async {
      final auth = service();
      await auth.setTokens('token', 'refresh');
      await auth.setUserName('Анна');

      await auth.updateUserName('  Аня ');

      expect(requests.single.method, 'PATCH');
      expect(requests.single.data, {'name': 'Аня'});
      expect(auth.userName, 'Аня');
      expect(await const FlutterSecureStorage().read(key: 'auth_user'), 'Аня');
    });

    test('ошибка сервера пробрасывается, имя на устройстве не меняется',
        () async {
      final auth = service();
      await auth.setTokens('token', 'refresh');
      await auth.setUserName('Анна');
      reply = () => json(422, {
            'status': 'error',
            'error': {'code': 'VALIDATION_ERROR', 'message': 'name'},
          });

      await expectLater(
          auth.updateUserName('Аня'), throwsA(isA<DioException>()));
      expect(auth.userName, 'Анна');
    });
  });

  group('Шапка «Профиля» и шторка имени', () {
    late HttpClientAdapter original;

    setUp(() async {
      original = ApiService.instance.dio.httpClientAdapter;
      ApiService.instance.dio.httpClientAdapter = _Adapter((options) async {
        requests.add(options);
        return reply();
      });
      await ApiService.instance.auth.setTokens('token', 'refresh');
      await ApiService.instance.auth.setUserName('Анна');
    });
    tearDown(() => ApiService.instance.dio.httpClientAdapter = original);

    Widget app({required bool isAuthenticated}) => MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ProfileHeader(
              userName: 'Анна',
              userEmail: 'anna@example.com',
              isAuthenticated: isAuthenticated,
            ),
          ),
        );

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(app(isAuthenticated: true));
      await tester.tap(find.byKey(const ValueKey('profile_edit_name')));
      await tester.pumpAndSettle();
    }

    bool saveEnabled(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.descendant(
            of: find.byKey(const ValueKey('edit_name_save')),
            matching: find.byType(ElevatedButton)))
        .enabled;

    testWidgets('у гостя имя не редактируется', (tester) async {
      await tester.pumpWidget(app(isAuthenticated: false));
      expect(find.byKey(const ValueKey('profile_edit_name')), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('нажатие на имя открывает шторку с текущим именем',
        (tester) async {
      await openSheet(tester);
      expect(find.text('Ваше имя'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('edit_name_field')))
              .controller!
              .text,
          'Анна');
      // Без изменений и с пустым именем сохранять нечего
      expect(saveEnabled(tester), isFalse);
      await tester.enterText(
          find.byKey(const ValueKey('edit_name_field')), '   ');
      await tester.pump();
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('«Сохранить» меняет имя на сервере и закрывает шторку',
        (tester) async {
      await openSheet(tester);
      await tester.enterText(
          find.byKey(const ValueKey('edit_name_field')), 'Аня');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.byKey(const ValueKey('edit_name_save')));
      await tester.pumpAndSettle();

      expect(requests.single.data, {'name': 'Аня'});
      expect(ApiService.instance.userName, 'Аня');
      expect(find.byType(EditNameSheet), findsNothing);
    });

    testWidgets('ошибка — шторка остаётся открытой, имя прежнее',
        (tester) async {
      reply = () => json(500, {
            'status': 'error',
            'error': {'code': 'INTERNAL_ERROR', 'message': 'boom'},
          });
      await openSheet(tester);
      await tester.enterText(
          find.byKey(const ValueKey('edit_name_field')), 'Аня');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit_name_save')));
      await tester.pumpAndSettle();

      expect(find.byType(EditNameSheet), findsOneWidget);
      expect(find.text('Не удалось сохранить имя'), findsOneWidget);
      expect(ApiService.instance.userName, 'Анна');
      expect(saveEnabled(tester), isTrue);
      // Дождаться таймера тоста
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
