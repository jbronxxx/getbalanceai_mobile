import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/auth/auth_cubit.dart';
import 'package:getbalanceai_mobile/cubits/insights/insights_cubit.dart';
import 'package:getbalanceai_mobile/cubits/profile/profile_cubit.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/utils/currency_formatter.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

class MockConnectivity extends Mock implements Connectivity {}

class MockLocalDbService extends Mock implements LocalDbService {}

void main() {
  late MockApiService api;
  late MockConnectivity connectivity;
  late StreamController<bool> authStreamController;

  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
    registerFallbackValue(CancelToken());
    LanguageManager.setLanguage(AppLanguage.ru);
  });

  setUp(() {
    api = MockApiService();
    connectivity = MockConnectivity();
    authStreamController = StreamController<bool>.broadcast();
    when(() => api.authStream).thenAnswer((_) => authStreamController.stream);
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
  });

  tearDown(() {
    authStreamController.close();
    LocalDbService.instance = null;
  });

  group('InsightsCubit', () {
    InsightsCubit build() =>
        InsightsCubit(api: api, connectivity: connectivity);

    blocTest<InsightsCubit, InsightsState>(
      'reacts to authStream emitting false by emitting InsightsUnauthenticated',
      build: build,
      act: (cubit) => authStreamController.add(false),
      expect: () => [isA<InsightsUnauthenticated>()],
    );

    blocTest<InsightsCubit, InsightsState>(
      'emits Unauthenticated when user is not logged in',
      setUp: () => when(() => api.isAuthenticated).thenReturn(false),
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [isA<InsightsUnauthenticated>()],
      verify: (_) => verifyNever(() => connectivity.checkConnectivity()),
    );

    blocTest<InsightsCubit, InsightsState>(
      'emits NetworkError when there is no connection',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => connectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);
      },
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [isA<InsightsNetworkError>()],
    );

    blocTest<InsightsCubit, InsightsState>(
      'emits Loading then Loaded with parsed insights and date',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.getInsights(
              currency: any(named: 'currency'),
              locale: any(named: 'locale'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              generate: any(named: 'generate'),
              cancelToken: any(named: 'cancelToken'),
            )).thenAnswer((_) async => {
              'insights': ['Tip A', 'Tip B'],
              'generated_at': '2026-10-02T13:45:00Z',
            });
      },
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsLoaded>()
            .having((s) => s.insights, 'insights', ['Tip A', 'Tip B']).having(
                (s) => s.generatedAt,
                'generatedAt',
                DateTime.parse('2026-10-02T13:45:00Z').toLocal()),
      ],
    );

    blocTest<InsightsCubit, InsightsState>(
      'emits Loaded with no-data placeholder when insights list is empty',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.getInsights(
              currency: any(named: 'currency'),
              locale: any(named: 'locale'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              generate: any(named: 'generate'),
              cancelToken: any(named: 'cancelToken'),
            )).thenAnswer((_) async => {'insights': <String>[]});
      },
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsLoaded>().having((s) => s.insights, 'insights',
            [LanguageManager.l10n.insight_no_data]),
      ],
    );

    blocTest<InsightsCubit, InsightsState>(
      'emits Error when API call fails',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.getInsights(
              currency: any(named: 'currency'),
              locale: any(named: 'locale'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              generate: any(named: 'generate'),
              cancelToken: any(named: 'cancelToken'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/insights/'),
          type: DioExceptionType.connectionTimeout,
        ));
      },
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsError>().having((s) => s.message, 'message', isNotEmpty),
      ],
    );

    blocTest<InsightsCubit, InsightsState>(
      'ignores cancelled requests without emitting Error',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.getInsights(
              currency: any(named: 'currency'),
              locale: any(named: 'locale'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              generate: any(named: 'generate'),
              cancelToken: any(named: 'cancelToken'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/insights/'),
          type: DioExceptionType.cancel,
        ));
      },
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [isA<InsightsLoading>()],
    );

    test('cancels in-flight request on close', () async {
      when(() => api.isAuthenticated).thenReturn(true);
      final completer = Completer<Map<String, dynamic>>();
      CancelToken? captured;
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) {
        captured = invocation.namedArguments[#cancelToken] as CancelToken;
        return completer.future;
      });

      final cubit = build();
      final future = cubit.loadInsights();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();

      expect(captured, isNotNull);
      expect(captured!.isCancelled, isTrue);

      completer.complete({
        'insights': ['late']
      });
      await future;
      expect(cubit.state, isA<InsightsLoading>());
    });

    test(
        'ignores language and currency change if insights were never loaded (_hasLoadedOnce is false)',
        () async {
      when(() => api.isAuthenticated).thenReturn(false);
      final cubit = build();

      LanguageManager.setLanguage(AppLanguage.en);
      CurrencyFormatter.setCurrency(Currency.eur);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<InsightsInitial>());
      expect(cubit.hasLoadedOnce, isFalse);

      await cubit.close();
      LanguageManager.setLanguage(AppLanguage.ru);
      CurrencyFormatter.setCurrency(Currency.usd);
    });

    test('reloads insights on language change if already loaded once',
        () async {
      when(() => api.isAuthenticated).thenReturn(false);
      final cubit = build();

      await cubit.loadInsights();
      expect(cubit.state, isA<InsightsUnauthenticated>());
      expect(cubit.hasLoadedOnce, isTrue);

      LanguageManager.setLanguage(AppLanguage.en);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<InsightsUnauthenticated>());

      await cubit.close();
      LanguageManager.setLanguage(AppLanguage.ru);
    });

    /// В выбранном месяце есть операции — анализ доступен, запрос к AI уходит.
    void stubMonthHasTransactions(MockLocalDbService mockDb) {
      when(() => mockDb.getTransactionsForPeriod(any(), any(),
          limit: any(named: 'limit'))).thenReturn([
        Transaction(
          amount: 50,
          description: 'Lunch',
          dbCategory: Category.food.name,
          dbType: TransactionType.expense.name,
          dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
          dateCreatedMilliseconds: 0,
        ),
      ]);
    }

    test(
        'calls syncLocalDataToBackend before getInsights when unsynced data exists',
        () async {
      final mockDb = MockLocalDbService();
      LocalDbService.instance = mockDb;
      stubMonthHasTransactions(mockDb);

      when(() => mockDb.getUnsyncedTransactions()).thenReturn([
        Transaction(
          localId: 1,
          amount: 100,
          description: 'Coffee',
          dbCategory: Category.food.name,
          dbType: TransactionType.expense.name,
          currencyCode: 'USD',
          dateMilliseconds: 1000,
          dateCreatedMilliseconds: 0,
        ),
      ]);
      when(() => mockDb.getUnsyncedBudgets()).thenReturn(<Budget>[]);
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.syncLocalDataToBackend()).thenAnswer((_) async => {});
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => {
            'insights': ['Synced tip'],
            'generated_at': '2026-10-02T13:45:00Z',
          });

      final cubit = build();
      await cubit.loadInsights();

      verify(() => api.syncLocalDataToBackend()).called(1);
      verify(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
      expect(cubit.state, isA<InsightsLoaded>());

      await cubit.close();
    });

    test(
        'proceeds with getInsights even if pre-sync syncLocalDataToBackend throws',
        () async {
      final mockDb = MockLocalDbService();
      LocalDbService.instance = mockDb;
      stubMonthHasTransactions(mockDb);

      when(() => mockDb.getUnsyncedTransactions()).thenReturn([
        Transaction(
          localId: 2,
          amount: 50,
          description: 'Lunch',
          dbCategory: Category.food.name,
          dbType: TransactionType.expense.name,
          currencyCode: 'USD',
          dateMilliseconds: 1000,
          dateCreatedMilliseconds: 0,
        ),
      ]);
      when(() => mockDb.getUnsyncedBudgets()).thenReturn(<Budget>[]);
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.syncLocalDataToBackend())
          .thenThrow(Exception('Network error during sync'));
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => {
            'insights': ['Fallback tip'],
            'generated_at': '2026-10-02T13:45:00Z',
          });

      final cubit = build();
      await cubit.loadInsights();

      verify(() => api.syncLocalDataToBackend()).called(1);
      verify(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
      expect(cubit.state, isA<InsightsLoaded>());

      await cubit.close();
    });

    test('does not call syncLocalDataToBackend when there is no unsynced data',
        () async {
      final mockDb = MockLocalDbService();
      LocalDbService.instance = mockDb;
      stubMonthHasTransactions(mockDb);

      when(() => mockDb.getUnsyncedTransactions()).thenReturn(<Transaction>[]);
      when(() => mockDb.getUnsyncedBudgets()).thenReturn(<Budget>[]);
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => {
            'insights': ['Tip without sync'],
            'generated_at': '2026-10-02T13:45:00Z',
          });

      final cubit = build();
      await cubit.loadInsights();

      verifyNever(() => api.syncLocalDataToBackend());
      verify(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
      expect(cubit.state, isA<InsightsLoaded>());

      await cubit.close();
    });

    /// Ответ бэкенда: при generate=false и [storedOnly] = null — not_generated.
    void stubInsights(
      List<String> insights, {
      List<String>? storedOnly,
    }) {
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((invocation) async {
        final generate = invocation.namedArguments[#generate] as bool;
        if (generate) return {'insights': insights, 'state': 'ready'};
        return storedOnly == null
            ? {'insights': <String>[], 'state': 'not_generated'}
            : {'insights': storedOnly, 'state': 'ready'};
      });
    }

    List<bool> capturedGenerateFlags() => verify(() => api.getInsights(
          currency: any(named: 'currency'),
          locale: any(named: 'locale'),
          month: any(named: 'month'),
          year: any(named: 'year'),
          generate: captureAny(named: 'generate'),
          cancelToken: any(named: 'cancelToken'),
        )).captured.cast<bool>();

    final now = DateTime.now();
    final previousMonth = MonthPeriod.current(now).previous;

    blocTest<InsightsCubit, InsightsState>(
      'past month without stored report: request without generation, then awaits user',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        stubInsights(['Generated']);
      },
      build: build,
      act: (cubit) => cubit.setPeriod(
        month: previousMonth.month,
        year: previousMonth.year,
      ),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsAwaitingRequest>().having(
            (s) => s.selectedMonth, 'selectedMonth', previousMonth.month),
      ],
      verify: (_) => expect(capturedGenerateFlags(), [false]),
    );

    blocTest<InsightsCubit, InsightsState>(
      'past month with stored report is shown automatically',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        stubInsights(['Generated'], storedOnly: ['Stored report']);
      },
      build: build,
      act: (cubit) => cubit.setPeriod(
        month: previousMonth.month,
        year: previousMonth.year,
      ),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsLoaded>()
            .having((s) => s.insights, 'insights', ['Stored report']),
      ],
      verify: (_) => expect(capturedGenerateFlags(), [false]),
    );

    blocTest<InsightsCubit, InsightsState>(
      'generate button for past month requests generation',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        stubInsights(['Generated']);
      },
      build: build,
      act: (cubit) async {
        cubit.setPeriod(month: previousMonth.month, year: previousMonth.year);
        await Future<void>.delayed(Duration.zero);
        await cubit.loadInsights();
      },
      skip: 2,
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsLoaded>()
            .having((s) => s.insights, 'insights', ['Generated']),
      ],
      verify: (_) => expect(capturedGenerateFlags(), [false, true]),
    );

    blocTest<InsightsCubit, InsightsState>(
      'future month is unavailable without any request',
      setUp: () => when(() => api.isAuthenticated).thenReturn(true),
      build: build,
      act: (cubit) {
        final next = MonthPeriod.current(now).next;
        cubit.setPeriod(month: next.month, year: next.year);
      },
      expect: () => [
        isA<InsightsUnavailable>().having(
            (s) => s.reason, 'reason', InsightsUnavailableReason.futureMonth),
      ],
      verify: (_) => verifyNever(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )),
    );

    blocTest<InsightsCubit, InsightsState>(
      'backend no_data maps to unavailable (no transactions)',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.getInsights(
              currency: any(named: 'currency'),
              locale: any(named: 'locale'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              generate: any(named: 'generate'),
              cancelToken: any(named: 'cancelToken'),
            )).thenAnswer((_) async => {'insights': [], 'state': 'no_data'});
      },
      build: build,
      act: (cubit) => cubit.loadInsights(),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsUnavailable>().having((s) => s.reason, 'reason',
            InsightsUnavailableReason.noTransactions),
      ],
    );

    test('returning to a loaded month uses session cache without request',
        () async {
      when(() => api.isAuthenticated).thenReturn(true);
      stubInsights(['Current report']);
      final cubit = build();

      await cubit.loadInsights();
      cubit.setPeriod(month: previousMonth.month, year: previousMonth.year);
      await Future<void>.delayed(Duration.zero);
      cubit.setPeriod(month: now.month, year: now.year);
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state,
        isA<InsightsLoaded>()
            .having((s) => s.insights, 'insights', ['Current report']),
      );
      // Текущий месяц — 1 генерация, прошлый — 1 запрос без генерации.
      expect(capturedGenerateFlags(), [true, false]);

      await cubit.close();
    });

    test('pull-to-refresh (force) bypasses session cache', () async {
      when(() => api.isAuthenticated).thenReturn(true);
      stubInsights(['First']);
      final cubit = build();

      await cubit.loadInsights();
      await cubit.loadInsights(force: true);

      expect(capturedGenerateFlags(), [true, true]);
      await cubit.close();
    });

    test('currency change requests only stored report, never generation',
        () async {
      when(() => api.isAuthenticated).thenReturn(true);
      stubInsights(['USD insight']);
      final cubit = build();
      await cubit.loadInsights();
      clearInteractions(api);

      CurrencyFormatter.setCurrency(Currency.eur);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<InsightsAwaitingRequest>());
      expect(capturedGenerateFlags(), [false]);

      await cubit.close();
      CurrencyFormatter.setCurrency(Currency.usd);
    });

    test('logout clears cached reports', () async {
      when(() => api.isAuthenticated).thenReturn(true);
      stubInsights(['Private insight']);
      final cubit = build();
      await cubit.loadInsights();

      authStreamController.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<InsightsUnauthenticated>());

      clearInteractions(api);
      await cubit.loadInsights();

      expect(capturedGenerateFlags(), [true]);
      await cubit.close();
    });

    test('setPeriod does not reload if period has not changed', () async {
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => {
            'insights': ['Initial']
          });

      final cubit = build();
      await cubit.loadInsights();
      clearInteractions(api);

      cubit.setPeriod(month: cubit.selectedMonth, year: cubit.selectedYear);
      verifyNever(() => api.getInsights(
            currency: any(named: 'currency'),
            locale: any(named: 'locale'),
            month: any(named: 'month'),
            year: any(named: 'year'),
            generate: any(named: 'generate'),
            cancelToken: any(named: 'cancelToken'),
          ));

      await cubit.close();
    });
  });

  group('ProfileCubit', () {
    ProfileCubit build() => ProfileCubit(api: api, connectivity: connectivity);

    blocTest<ProfileCubit, ProfileState>(
      'emits noInternet and skips sync when offline',
      setUp: () => when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]),
      build: build,
      act: (cubit) => cubit.startSync(),
      expect: () => [
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.noInternet),
      ],
      verify: (_) => verifyNever(() => api.syncAll()),
    );

    blocTest<ProfileCubit, ProfileState>(
      'emits syncing then success on successful sync',
      setUp: () => when(() => api.syncAll()).thenAnswer((_) async => {}),
      build: build,
      act: (cubit) => cubit.startSync(),
      expect: () => [
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.syncing),
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.success)
            .having((s) => s.syncError, 'syncError', isNull),
      ],
    );

    final syncFailure = Exception('sync failed');
    blocTest<ProfileCubit, ProfileState>(
      'emits syncing then error with stored exception on failure',
      setUp: () => when(() => api.syncAll()).thenThrow(syncFailure),
      build: build,
      act: (cubit) => cubit.startSync(),
      expect: () => [
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.syncing),
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.error)
            .having((s) => s.syncError, 'syncError', syncFailure),
      ],
    );

    blocTest<ProfileCubit, ProfileState>(
      'ignores repeated startSync while sync is in progress',
      setUp: () => when(() => api.syncAll()).thenAnswer(
          (_) => Future.delayed(const Duration(milliseconds: 10), () => {})),
      build: build,
      act: (cubit) async {
        final first = cubit.startSync();
        await Future<void>.delayed(Duration.zero);
        await cubit.startSync();
        await first;
      },
      expect: () => [
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.syncing),
        isA<ProfileState>()
            .having((s) => s.syncStatus, 'syncStatus', SyncStatus.success),
      ],
      verify: (_) => verify(() => api.syncAll()).called(1),
    );

    blocTest<ProfileCubit, ProfileState>(
      'logout delegates to ApiService',
      setUp: () => when(() => api.logout()).thenAnswer(
          (_) async => LogoutResponseModel(status: 'success', message: 'ok')),
      build: build,
      act: (cubit) => cubit.logout(),
      expect: () => <ProfileState>[],
      verify: (_) => verify(() => api.logout()).called(1),
    );

    test('logout completes without throwing when server call fails', () async {
      when(() => api.logout()).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/auth/logout'),
        type: DioExceptionType.connectionError,
      ));
      final cubit = build();
      await expectLater(cubit.logout(), completes);
      await cubit.close();
    });

    test('LogoutResponseModel parses plain, wrapped and empty payloads', () {
      final plain =
          LogoutResponseModel.fromJson({'status': 'success', 'message': 'Bye'});
      expect(plain.status, 'success');
      expect(plain.message, 'Bye');

      final wrapped = LogoutResponseModel.fromJson({
        'data': {'message': 'Wrapped'}
      });
      expect(wrapped.message, 'Wrapped');

      final empty = LogoutResponseModel.fromJson(null);
      expect(empty.status, 'success');
      expect(empty.message, '');
    });

    test('copyWith clears syncError unless provided', () {
      final error = Exception('x');
      const base = ProfileState();
      final withError =
          base.copyWith(syncStatus: SyncStatus.error, syncError: error);
      expect(withError.syncError, error);
      expect(
          withError.copyWith(syncStatus: SyncStatus.syncing).syncError, isNull);
    });
  });

  group('AuthCubit', () {
    test('emits Unauthenticated initially when user is not authenticated', () {
      when(() => api.isAuthenticated).thenReturn(false);
      final cubit = AuthCubit(apiService: api);
      expect(cubit.state, isA<Unauthenticated>());
      cubit.close();
    });

    test(
        'emits Authenticated with email, name and avatarUrl when authenticated',
        () {
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.email).thenReturn('user@example.com');
      when(() => api.userName).thenReturn('Google User');
      when(() => api.avatarUrl)
          .thenReturn('https://lh3.googleusercontent.com/avatar');

      final cubit = AuthCubit(apiService: api);
      expect(cubit.state, isA<Authenticated>());
      final authState = cubit.state as Authenticated;
      expect(authState.email, 'user@example.com');
      expect(authState.name, 'Google User');
      expect(authState.avatarUrl, 'https://lh3.googleusercontent.com/avatar');
      cubit.close();
    });

    blocTest<AuthCubit, AuthState>(
      'reacts to authStream emitting false by emitting Unauthenticated',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.email).thenReturn('u@example.com');
        when(() => api.userName).thenReturn('User');
        when(() => api.avatarUrl).thenReturn(null);
      },
      build: () => AuthCubit(apiService: api),
      act: (cubit) {
        when(() => api.isAuthenticated).thenReturn(false);
        authStreamController.add(false);
      },
      expect: () => [isA<Unauthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'reacts to authStream emitting true with updated avatarUrl',
      setUp: () {
        when(() => api.isAuthenticated).thenReturn(false);
      },
      build: () => AuthCubit(apiService: api),
      act: (cubit) {
        when(() => api.isAuthenticated).thenReturn(true);
        when(() => api.email).thenReturn('u@example.com');
        when(() => api.userName).thenReturn('User');
        when(() => api.avatarUrl)
            .thenReturn('https://lh3.googleusercontent.com/new_avatar');
        authStreamController.add(true);
      },
      expect: () => [
        isA<Authenticated>().having((s) => s.avatarUrl, 'avatarUrl',
            'https://lh3.googleusercontent.com/new_avatar'),
      ],
    );

    test('logout delegates to performLogout', () {
      when(() => api.isAuthenticated).thenReturn(true);
      when(() => api.email).thenReturn('u@example.com');
      when(() => api.userName).thenReturn('User');
      when(() => api.avatarUrl).thenReturn(null);
      when(() => api.performLogout()).thenAnswer((_) async {});

      final cubit = AuthCubit(apiService: api);
      cubit.logout();
      verify(() => api.performLogout()).called(1);
      cubit.close();
    });
  });
}
