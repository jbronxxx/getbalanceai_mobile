import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import '../config/api_config.dart';
import '../config/environment.dart';
import '../config/secure_storage_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';
import 'app_info_service.dart';
import 'auth_api_service.dart';
import 'budget_api_service.dart';
import 'report_export_service.dart';
import 'sync_service.dart';
import 'tracing_interceptor.dart';
import 'transaction_api_service.dart';

/// Единый сетевой клиент приложения (Facade), объединяющий доменные сервисы:
/// [AuthApiService], [TransactionApiService], [BudgetApiService] и [SyncService].
class ApiService {
  static const String _kRetriedKey = 'retried';
  static const String _kTimezoneOffsetHeader = 'X-Timezone-Offset';

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
    _authService = AuthApiService(
      dio: _dio,
      onSignIn: (userId) => _syncService.claimLocalData(userId),
    );
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
      userIdProvider: () => _authService.userId,
    );

    EnvironmentConfig.addEnvironmentListener((_) async {
      await onEnvironmentChanged();
    });

    _dio.interceptors.add(TracingInterceptor());
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Месяцы бюджетов и AI-отчётов сервер считает по часам пользователя
        if (!_isForeignHost(options.path)) {
          options.headers[_kTimezoneOffsetHeader] =
              DateTime.now().timeZoneOffset.inMinutes.toString();
          options.headers.addAll(AppInfoService.instance.clientHeaders);
        }
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

          final String? newAccessToken;
          try {
            newAccessToken = await _authService.performTokenRefresh();
          } on DioException catch (refreshError) {
            // Сессия жива, обновить токен помешал временный сбой (сеть, 429,
            // 5xx): вызывающий получает его, а не исходный 401 — иначе
            // показал бы «Сессия истекла».
            return handler.reject(
              refreshError.copyWith(requestOptions: e.requestOptions),
            );
          } catch (refreshError) {
            AppLogger.e('[ApiService] Token refresh crashed', refreshError);
            return handler.reject(e);
          }
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

  /// Абсолютный URL на чужой хост: служебные заголовки бэкенда туда не уходят.
  static bool _isForeignHost(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    final baseUri = Uri.tryParse(ApiConfig.baseUrl);
    return baseUri != null && uri.host.isNotEmpty && uri.host != baseUri.host;
  }

  static bool _isAuthExcludedPath(String path) {
    if (_isForeignHost(path)) return true;
    final uri = Uri.tryParse(path);
    final pathOnly = uri?.path ?? path.split('?').first;
    return pathOnly == ApiConfig.refreshToken ||
        pathOnly == ApiConfig.loginGoogle ||
        pathOnly == ApiConfig.loginApple ||
        pathOnly == ApiConfig.currencyRates;
  }

  static bool _isAuthPath(String path) => path.startsWith('/auth/');

  /// Базовый экземпляр Dio с настроенными интерцепторами трассировки,
  /// безопасной авторизации и логирования.
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
    await resetSession();
  }

  Future<void> init() async {
    // Одно обращение к Keystore/Keychain вместо отдельного на каждый ключ
    final stored = await appSecureStorage.readAll();
    await _authService.init(stored);
    await _syncService.init(stored);
    // Установки, где владелец данных ещё не записан: данные на устройстве
    // принадлежат вошедшему пользователю.
    final userId = _authService.userId;
    if (_authService.isAuthenticated && userId != null) {
      await _syncService.claimLocalData(userId);
    }
  }

  /// Очищает сессию и ETag. ETag сбрасываются первыми: их ключи привязаны
  /// к userId, который очистка сессии обнуляет.
  Future<void> clearAllUserData() async {
    await _syncService.clearEtags();
    await _authService.clearAllUserData();
  }

  /// [clearAllUserData] с событием выхода в [authStream] — для отладочного
  /// меню и смены окружения: без события экраны продолжали бы показывать
  /// вошедшего пользователя, у которого уже нет токена.
  Future<void> resetSession() async {
    await clearAllUserData();
    _authService.notifyLoggedOut();
  }

  /// Стирает с устройства данные пользователя [userId]: операции, лимиты,
  /// очередь удалений, ETag и выгруженные отчёты. Вызывается после очистки
  /// сессии, чтобы синк, поставленный в очередь позже, уже не запустился.
  Future<void> _clearAccountData(String? userId) async {
    await _syncService.clearLocalData(userId: userId);
    await ReportExportService.deleteCachedReports();
  }

  Future<void> clearEtags() => _syncService.clearEtags();

  Future<void> loginWithGoogle(
    String idToken, {
    String? avatarUrl,
    String? name,
  }) =>
      _authService.loginWithGoogle(
        idToken,
        avatarUrl: avatarUrl,
        name: name,
      );

  Future<void> loginWithApple(String identityToken) =>
      _authService.loginWithApple(identityToken);

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

  /// Меняет имя пользователя; ошибка сервера или сети пробрасывается.
  Future<void> updateUserName(String name) => _authService.updateUserName(name);

  /// Удаляет аккаунт на сервере и все его данные на устройстве. При ошибке
  /// сервера ничего не стирается и сессия сохраняется.
  Future<void> deleteAccount() async {
    final userId = _authService.userId;
    await _authService.deleteAccount();
    await _clearAccountData(userId);
    _authService.notifyLoggedOut();
  }

  /// Выход из аккаунта: отзывает сессию на сервере и стирает данные
  /// пользователя с устройства, чтобы их не увидел гость и они не ушли в
  /// следующий аккаунт. Ошибка сервера пробрасывается, но локальный выход
  /// выполняется в любом случае.
  Future<void> logout() async {
    final userId = _authService.userId;
    try {
      await _authService.logout();
    } finally {
      await _clearAccountData(userId);
      _authService.notifyLoggedOut();
    }
  }

  // Transactions
  Future<void> deleteTransactionEverywhere(Transaction transaction) =>
      _transactionApiService.deleteTransactionEverywhere(transaction);

  // Budgets
  Future<void> deleteBudgetEverywhere(Budget budget) =>
      _budgetApiService.deleteBudgetEverywhere(budget);

  // Sync
  Future<Map<String, dynamic>> syncLocalDataToBackend() =>
      _syncService.syncLocalDataToBackend();

  /// Отправляет локальные правки на сервер в фоне, если пользователь вошёл.
  /// Ошибка только пишется в журнал: правки остаются помеченными и уйдут
  /// со следующей синхронизацией.
  void pushLocalChangesInBackground() {
    if (!isAuthenticated) return;
    unawaited(
      syncLocalDataToBackend().catchError((Object e, StackTrace s) {
        AppLogger.w('[Sync] Background push failed', e, s);
        return <String, dynamic>{};
      }),
    );
  }

  Future<Map<String, dynamic>> syncAll() => _syncService.syncAll();

  // Insights
  Future<Map<String, dynamic>> getInsights({
    String? currency,
    String? locale,
    int? month,
    int? year,
    bool generate = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.insights,
        queryParameters: {
          if (currency != null) 'currency': currency,
          if (locale != null) 'locale': locale,
          if (month != null) 'month': month,
          if (year != null) 'year': year,
          // false — только сохранённый отчёт, без вызова LLM
          if (!generate) 'generate': false,
        },
        options: Options(
          // Бэкенд ждёт ИИ до AI_REQUEST_TIMEOUT (30 с) и отвечает
          // state=busy; клиент не должен оборвать запрос раньше.
          receiveTimeout: const Duration(seconds: 45),
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

  // Voice input

  /// Разбирает распознанную фразу на черновики записей (сервер их не
  /// сохраняет). [currency] — валюта записи, если в фразе её нет; [locale] —
  /// язык интерфейса. Пустой список — в фразе нет ни одной суммы. Ошибки —
  /// как есть: 429 `AI_QUOTA_EXCEEDED` (квота на сутки), 503, сеть.
  Future<List<Transaction>> parseVoice({
    required String text,
    required String locale,
    required Currency currency,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.voiceParse,
        data: {'text': text, 'locale': locale, 'currency': currency.code},
        options: Options(
          // Бэкенд ждёт ИИ до AI_REQUEST_TIMEOUT (30 с), затем отвечает 503
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );
      return VoiceDrafts.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } catch (e) {
      // Текст фразы в журнал не пишется: в нём траты пользователя
      AppLogger.e('[ApiService] Voice parse error', e);
      rethrow;
    }
  }
}
