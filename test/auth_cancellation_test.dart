import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:getbalanceai_mobile/utils/app_error_handler.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
  });

  group('AppErrorHandler.isUserCanceled Tests', () {
    test('Распознает отмену GoogleSignInExceptionCode.canceled', () {
      const err = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'User canceled flow',
      );
      expect(AppErrorHandler.isUserCanceled(err), isTrue);
    });

    test('Не считает ошибку GoogleSignInExceptionCode.unknownError отменой',
        () {
      const err = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Unknown network issue',
      );
      expect(AppErrorHandler.isUserCanceled(err), isFalse);
    });

    test('Распознает отмену Apple AuthorizationErrorCode.canceled', () {
      const err = SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'The user canceled authorization.',
      );
      expect(AppErrorHandler.isUserCanceled(err), isTrue);
    });

    test('Не считает ошибку Apple AuthorizationErrorCode.failed отменой', () {
      const err = SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.failed,
        message: 'Authorization failed.',
      );
      expect(AppErrorHandler.isUserCanceled(err), isFalse);
    });

    test(
        'Распознает различные коды отмены PlatformException (sign_in_canceled, 12501, 16)',
        () {
      expect(
        AppErrorHandler.isUserCanceled(
          PlatformException(code: 'sign_in_canceled'),
        ),
        isTrue,
      );
      expect(
        AppErrorHandler.isUserCanceled(
          PlatformException(code: 'canceled'),
        ),
        isTrue,
      );
      expect(
        AppErrorHandler.isUserCanceled(
          PlatformException(code: '12501'),
        ),
        isTrue,
      );
      expect(
        AppErrorHandler.isUserCanceled(
          PlatformException(code: '16'),
        ),
        isTrue,
      );
      expect(
        AppErrorHandler.isUserCanceled(
          PlatformException(
            code: 'error',
            message: 'com.google.android.gms.common.api.ApiException: canceled',
          ),
        ),
        isTrue,
      );
    });

    test('Не считает сетевую ошибку DioException отменой', () {
      final reqOptions = RequestOptions(path: '/auth/google');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 401,
          data: {'message': 'Недействительный токен Google'},
        ),
      );
      expect(AppErrorHandler.isUserCanceled(err), isFalse);
    });

    test('Не считает стандартные исключения без признаков отмены отменой', () {
      expect(
          AppErrorHandler.isUserCanceled(Exception('Database error')), isFalse);
      expect(AppErrorHandler.isUserCanceled(null), isFalse);
    });
  });

  group('AppErrorHandler.show Cancellation Dialog Suppression Tests', () {
    testWidgets('При отмене GoogleSignIn диалог ошибки не показывается',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  const err = GoogleSignInException(
                    code: GoogleSignInExceptionCode.canceled,
                  );
                  AppErrorHandler.show(context, err);
                },
                child: const Text('Trigger Error'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      // Диалог ошибки не должен отображаться
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('При отмене Apple Sign In диалог ошибки не показывается',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  const err = SignInWithAppleAuthorizationException(
                    code: AuthorizationErrorCode.canceled,
                    message: 'User canceled',
                  );
                  AppErrorHandler.show(context, err);
                },
                child: const Text('Trigger Error'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('При реальной ошибке уведомление об ошибке штатно отображается',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppErrorHandler.show(
                    context,
                    Exception('Server unreachable'),
                    title: 'Ошибка сервера',
                  );
                },
                child: const Text('Trigger Error'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Trigger Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Ошибка сервера'), findsOneWidget);
    });
  });
}
