import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import '../config/api_config.dart';
import '../config/environment.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import 'auth_api_service.dart';
import 'budget_api_service.dart';
import 'sync_service.dart';
import 'tracing_interceptor.dart';
import 'transaction_api_service.dart';

/// Единый сетевой клиент приложения (Facade), объединяющий доменные сервисы:
/// [AuthApiService], [TransactionApiService], [BudgetApiService] и [SyncService].
class ApiService {
  static const String _kRetriedKey = 'retried';

  final Dio _dio;
  late final AuthApiService _authService;
  late final TransactionApiService _transactionApiService;
  late final BudgetApiService _budgetApiService;
  late final SyncService _syncService;

  static final ApiService instance = ApiService._internal();

  ApiService._internal()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
        )) {
    _authService = AuthApiService(dio: _dio);
    _transactionApiService = TransactionApiService(
      dio: _dio,
      authOptions: _authService.authOptions,
      isAuthenticated: () => _authService.isAuthenticated,
    );
    _budgetApiService = BudgetApiService(
      dio: _dio,
      authOptions: _authService.authOptions,
      isAuthenticated: () => _authService.isAuthenticated,
    );
    _syncService = SyncService(
      dio: _dio,
      authOptions: _authService.authOptions,
      tokenProvider: () => _authService.token,
      transactionApiService: _transactionApiService,
      budgetApiService: _budgetApiService,
    );

    EnvironmentConfig.addEnvironmentListener((_) async {
      await onEnvironmentChanged();
    });

    _dio.interceptors.add(TracingInterceptor());
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _authService.token;
        if (token != null &&
            !options.headers.containsKey('Authorization') &&
            !_isAuthExcludedPath(options.path)) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.requestOptions.extra[_kRetriedKey] == true) {
          return handler.next(e);
        }

        if (e.response?.statusCode == 401 &&
            !_isAuthExcludedPath(e.requestOptions.path)) {
          final currentAuth = e.requestOptions.headers['Authorization'];

          if (_authService.token != null &&
              currentAuth != null &&
              currentAuth != 'Bearer ${_authService.token}') {
            final options = e.requestOptions;
            options.headers['Authorization'] = 'Bearer ${_authService.token}';
            options.extra[_kRetriedKey] = true;
            try {
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            } catch (retryErr) {
              if (retryErr is DioException) {
                return handler.next(retryErr);
              }
              return handler.reject(e);
            }
          }

          final newAccessToken = await _authService.performTokenRefresh();
          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            final options = e.requestOptions;
            options.headers['Authorization'] = 'Bearer $newAccessToken';
            options.extra[_kRetriedKey] = true;
            try {
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            } catch (retryErr) {
              if (retryErr is DioException) {
                return handler.next(retryErr);
              }
              return handler.reject(e);
            }
          } else {
            return handler.reject(e);
          }
        }
        return handler.next(e);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(TalkerDioLogger(
        talker: talker,
        settings: TalkerDioLoggerSettings(
          printRequestHeaders: false,
          printResponseHeaders: false,
          printResponseMessage: true,
          requestFilter: (o) => !_isAuthPath(o.path),
          responseFilter: (r) => !_isAuthPath(r.requestOptions.path),
        ),
      ));
    }
  }

  static bool _isAuthExcludedPath(String path) {
    final cleanPath = path.split('?').first;
    return cleanPath == ApiConfig.refreshToken ||
        cleanPath == ApiConfig.login ||
        cleanPath == ApiConfig.register ||
        cleanPath == ApiConfig.loginGoogle ||
        cleanPath == ApiConfig.loginApple;
  }

  static bool _isAuthPath(String path) => path.startsWith('/auth/');

  @visibleForTesting
  Dio get dio => _dio;

  AuthApiService get auth => _authService;
  TransactionApiService get transactions => _transactionApiService;
  BudgetApiService get budgets => _budgetApiService;
  SyncService get sync => _syncService;

  Stream<bool> get authStream => _authService.authStream;
  String? get userName => _authService.userName;
  String? get email => _authService.email;
  String? get avatarUrl => _authService.avatarUrl;
  bool get isAuthenticated => _authService.isAuthenticated;

  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  Future<void> onEnvironmentChanged() async {
    updateBaseUrl(ApiConfig.baseUrl);
    await clearAllUserData();
  }

  Future<void> init() async {
    await _authService.init();
    await _syncService.init();
  }

  Future<void> setTokens(String? token, String? refresh) =>
      _authService.setTokens(token, refresh);

  Future<void> setUserName(String? userName) =>
      _authService.setUserName(userName);

  Future<void> setAvatarUrl(String? avatarUrl) =>
      _authService.setAvatarUrl(avatarUrl);

  Future<void> setUserEmail(String? email) => _authService.setUserEmail(email);

  Future<void> clearAllUserData() async {
    await _authService.clearAllUserData();
    await _syncService.clearEtags();
  }

  Future<RegisterModel> register({
    required String email,
    required String password,
    required String name,
  }) =>
      _authService.register(email: email, password: password, name: name);

  Future<LoginResponseModel> login({
    required String email,
    required String password,
  }) =>
      _authService.login(email: email, password: password);

  Future<LoginResponseModel> loginWithGoogle(String idToken) =>
      _authService.loginWithGoogle(idToken);

  Future<LoginResponseModel> loginWithApple(String identityToken) =>
      _authService.loginWithApple(identityToken);

  Future<void> fetchAndSaveUserProfile() =>
      _authService.fetchAndSaveUserProfile();

  Future<void> updateUserProfile({
    String? name,
    String? avatarUrl,
    String? baseCurrency,
  }) =>
      _authService.updateUserProfile(
        name: name,
        avatarUrl: avatarUrl,
        baseCurrency: baseCurrency,
      );

  Future<void> deleteAccount() => _authService.deleteAccount();

  Future<LogoutResponseModel> logout() => _authService.logout();

  Future<void> performLogout() => _authService.performLogout();

  Future<bool> refreshAuthTokens() => _authService.refreshAuthTokens();

  // Transactions
  Future<PaginatedResponse<TransactionModel>> getTransactions({
    int limit = 50,
    String? cursor,
    DateTime? since,
  }) =>
      _transactionApiService.getTransactions(
          limit: limit, cursor: cursor, since: since);

  Future<TransactionModel> createTransaction(Map<String, dynamic> data) =>
      _transactionApiService.createTransaction(data);

  Future<void> deleteTransaction(String id, [String? token]) =>
      _transactionApiService.deleteTransaction(id, token);

  Future<void> deleteTransactionEverywhere(Transaction transaction) =>
      _transactionApiService.deleteTransactionEverywhere(transaction);

  // Budgets
  Future<List<BudgetModel>> getBudgets({int? month, int? year}) =>
      _budgetApiService.getBudgets(month: month, year: year);

  Future<BudgetModel> createBudget(Map<String, dynamic> data) =>
      _budgetApiService.createBudget(data);

  Future<BudgetModel> updateBudget(Map<String, dynamic> data) =>
      _budgetApiService.updateBudget(data);

  Future<void> deleteBudget(String id, [String? token]) =>
      _budgetApiService.deleteBudget(id, token);

  Future<void> deleteBudgetByPeriod(
    String category,
    int month,
    int year, [
    String? token,
  ]) =>
      _budgetApiService.deleteBudgetByPeriod(category, month, year, token);

  Future<void> deleteBudgetEverywhere(Budget budget) =>
      _budgetApiService.deleteBudgetEverywhere(budget);

  // Sync
  Future<Map<String, dynamic>> syncLocalDataToBackend([String? token]) =>
      _syncService.syncLocalDataToBackend(token);

  Future<Map<String, dynamic>> syncBackendDataToLocal([
    String? token,
    void Function(int count, int page)? onTransactionProgress,
    int maxPages = 100,
  ]) =>
      _syncService.syncBackendDataToLocal(
          token, onTransactionProgress, maxPages);

  Future<Map<String, dynamic>> syncAll([
    String? token,
    void Function(int count, int page)? onTransactionProgress,
    int maxPages = 100,
  ]) =>
      _syncService.syncAll(token, onTransactionProgress, maxPages);

  // Insights & Health
  Future<Map<String, dynamic>> getInsights({
    String? currency,
    String? locale,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.insights,
        queryParameters: {
          if (currency != null) 'currency': currency,
          if (locale != null) 'locale': locale,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      return response.data['data'] as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('[ApiService] Get insights error', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _dio.get(ApiConfig.health);
      return response.data is Map
          ? (response.data as Map).cast<String, dynamic>()
          : {'status': 'ok'};
    } catch (e) {
      AppLogger.e('[ApiService] Health check error', e);
      rethrow;
    }
  }
}
