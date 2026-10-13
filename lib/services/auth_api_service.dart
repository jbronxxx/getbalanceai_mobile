import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';
import 'api_service.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';

/// Сервис аутентификации, сессий и управления токенами доступа.
class AuthApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final StreamController<bool> _authStream = StreamController.broadcast();

  String? _token;
  String? _refreshToken;
  Completer<String?>? _refreshCompleter;
  String? _userId;
  String? _userName;
  String? _email;
  String? _avatarUrl;

  AuthApiService({
    required Dio dio,
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  })  : _dio = dio,
        _storage = storage;

  Stream<bool> get authStream => _authStream.stream;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get email => _email;
  String? get avatarUrl => _avatarUrl;
  bool get isAuthenticated => _token != null;

  Options authOptions([String? explicitToken]) {
    final t = explicitToken ?? _token;
    return Options(headers: {
      if (t != null) 'Authorization': 'Bearer $t',
    });
  }

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    _userId = await _storage.read(key: 'auth_user_id');
    _userName = await _storage.read(key: 'auth_user');
    _email = await _storage.read(key: 'auth_email');
    _avatarUrl = await _storage.read(key: 'auth_avatar_url');
  }

  Future<void> setTokens(String? token, String? refresh) async {
    _token = token;
    _refreshToken = refresh;

    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'refresh_token', value: refresh);
      final extracted = _extractUserIdFromToken(token);
      if (extracted != null && _userId == null) {
        await setUserId(extracted);
      }
    } else {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
      await setUserId(null);
    }
  }

  static String? _extractUserIdFromToken(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final payloadString = utf8.decode(base64Url.decode(normalized));
        final payload = jsonDecode(payloadString);
        if (payload is Map) {
          final sub = payload['sub'] ?? payload['user_id'] ?? payload['id'];
          return sub?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    if (userId != null) {
      await _storage.write(key: 'auth_user_id', value: userId);
    } else {
      await _storage.delete(key: 'auth_user_id');
    }
  }

  Future<void> setUserName(String? userName) async {
    if (userName != null) {
      _userName = userName;
      await _storage.write(key: 'auth_user', value: userName);
      if (isAuthenticated) {
        _authStream.add(true);
      }
    }
  }

  Future<void> setAvatarUrl(String? avatarUrl) async {
    _avatarUrl = avatarUrl;
    if (avatarUrl != null) {
      await _storage.write(key: 'auth_avatar_url', value: avatarUrl);
    } else {
      await _storage.delete(key: 'auth_avatar_url');
    }
    if (isAuthenticated) {
      _authStream.add(true);
    }
  }

  Future<void> setUserEmail(String? email) async {
    if (email != null) {
      _email = email;
      await _storage.write(key: 'auth_email', value: email);
    }
  }

  Future<void> clearAllUserData() async {
    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'auth_user_id');
      await _storage.delete(key: 'auth_user');
      await _storage.delete(key: 'auth_email');
      await _storage.delete(key: 'auth_avatar_url');
      await _storage.delete(key: 'transactions_etag');
      await _storage.delete(key: 'budgets_etag');
    } catch (e) {
      AppLogger.w('[AuthApiService] Secure storage clear error: $e');
    }

    try {
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId: ApiConfig.googleServerClientId,
        );
      } catch (e) {
        AppLogger.w(
            '[AuthApiService] Google initialize before signOut error: $e');
      }
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      AppLogger.w('[AuthApiService] Google signOut error: $e');
    }

    _token = null;
    _refreshToken = null;
    _userId = null;
    _userName = null;
    _email = null;
    _avatarUrl = null;
  }

  Future<void> handleSessionExpired() async {
    await clearAllUserData();
    _authStream.add(false);
  }

  Future<RegisterModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final RegisterModel registerResponse;
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );

      registerResponse = RegisterModel.fromJson(response.data);
      await setUserName(registerResponse.name);
      await setUserEmail(registerResponse.email);
    } on DioException catch (e) {
      AppLogger.e(
          '[AuthApiService] Register error: ${e.response?.data ?? e.message}',
          e);
      rethrow;
    }

    try {
      await login(email: registerResponse.email, password: password);
      return registerResponse;
    } catch (e) {
      AppLogger.w('[AuthApiService] Login after register error: $e');
      rethrow;
    }
  }

  Future<LoginResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data['data'];
      final token = data?['access_token'] as String?;
      final refreshToken = data?['refresh_token'] as String?;

      if (token == null || refreshToken == null) {
        throw Exception('Сервер не вернул токены');
      }

      await setTokens(token, refreshToken);
      await setUserEmail(email);
      await fetchAndSaveUserProfile();

      _authStream.add(true);
      return LoginResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.e(
          '[AuthApiService] Login error: ${e.response?.data ?? e.message}', e);
      rethrow;
    }
  }

  Future<LoginResponseModel> loginWithGoogle(
    String idToken, {
    String? avatarUrl,
    String? name,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id_token': idToken,
      };
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        payload['avatar_url'] = avatarUrl;
      }
      if (name != null && name.isNotEmpty) {
        payload['name'] = name;
      }

      final response = await _dio.post(
        ApiConfig.loginGoogle,
        data: payload,
      );

      return _handleLoginResponse(response.data);
    } on DioException catch (e) {
      AppLogger.e(
          '[AuthApiService] Google login error: ${e.response?.data ?? e.message}',
          e);
      rethrow;
    }
  }

  Future<LoginResponseModel> loginWithApple(String identityToken) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginApple,
        data: {'identity_token': identityToken},
      );

      return _handleLoginResponse(response.data);
    } on DioException catch (e) {
      AppLogger.e(
          '[AuthApiService] Apple login error: ${e.response?.data ?? e.message}',
          e);
      rethrow;
    }
  }

  Future<LoginResponseModel> _handleLoginResponse(dynamic responseData) async {
    final data = responseData['data'];
    final token = data?['access_token'] as String?;
    final refreshToken = data?['refresh_token'] as String?;

    if (token == null || refreshToken == null) {
      throw Exception('Сервер не вернул токены');
    }

    await setTokens(token, refreshToken);

    if (data?['user'] != null && data['user'] is Map<String, dynamic>) {
      try {
        final userProfile =
            AuthMeResponseModel.fromJson({'data': data['user']});
        await setUserId(userProfile.id);
        await setUserName(userProfile.userName);
        await setUserEmail(userProfile.userEmail);
        await setAvatarUrl(userProfile.avatarUrl);
        if (userProfile.baseCurrency != null) {
          final currency = Currency.values.firstWhere(
            (c) =>
                c.code.toUpperCase() == userProfile.baseCurrency!.toUpperCase(),
            orElse: () => CurrencyFormatter.currentCurrency,
          );
          await CurrencyFormatter.setCurrency(currency);
        }
        AppLogger.i(
            '[AuthApiService] Profile populated from login tokens for: ${userProfile.userName}');
      } catch (e) {
        AppLogger.w('[AuthApiService] Token profile parse error: $e');
        await fetchAndSaveUserProfile();
      }
    } else {
      await fetchAndSaveUserProfile();
    }

    _authStream.add(true);
    return LoginResponseModel.fromJson(responseData);
  }

  Future<void> fetchAndSaveUserProfile() async {
    try {
      final response = await _dio.get(
        ApiConfig.me,
        options: authOptions(),
      );

      final userProfile = AuthMeResponseModel.fromJson(response.data);
      await setUserId(userProfile.id);
      await setUserName(userProfile.userName);
      await setUserEmail(userProfile.userEmail);
      await setAvatarUrl(userProfile.avatarUrl);
      if (userProfile.baseCurrency != null) {
        final currency = Currency.values.firstWhere(
          (c) =>
              c.code.toUpperCase() == userProfile.baseCurrency!.toUpperCase(),
          orElse: () => CurrencyFormatter.currentCurrency,
        );
        await CurrencyFormatter.setCurrency(currency);
      }
      AppLogger.i(
          '[AuthApiService] Profile updated for: ${userProfile.userName}');
    } on DioException catch (e) {
      AppLogger.w(
          '[AuthApiService] Fetch profile error: ${e.response?.data ?? e.message}');
    } catch (e) {
      AppLogger.w('[AuthApiService] Profile parse error: $e');
    }
  }

  /// Обновляет профиль пользователя на сервере (имя, аватар, базовая валюта).
  Future<void> updateUserProfile({
    String? name,
    String? avatarUrl,
    String? baseCurrency,
  }) async {
    if (!isAuthenticated) return;
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (baseCurrency != null) data['base_currency'] = baseCurrency;

      if (data.isEmpty) return;

      await _dio.patch(
        ApiConfig.me,
        data: data,
        options: authOptions(),
      );
      if (name != null) await setUserName(name);
      if (avatarUrl != null) await setAvatarUrl(avatarUrl);

      if (baseCurrency != null) {
        await _storage.delete(key: 'transactions_etag');
        await _storage.delete(key: 'budgets_etag');
        try {
          await ApiService.instance.clearEtags();
          unawaited(() async {
            try {
              await ApiService.instance.syncAll();
              CurrencyFormatter.notifyCurrencyChanged();
            } catch (e) {
              AppLogger.w(
                  '[AuthApiService] Background sync after currency change failed: $e');
            }
          }());
        } catch (e) {
          AppLogger.w('[AuthApiService] Resetting ETags/Sync failed: $e');
        }
      }

      AppLogger.i('[AuthApiService] Remote user profile updated: $data');
    } on DioException catch (e) {
      AppLogger.w(
          '[AuthApiService] Update profile error: ${e.response?.data ?? e.message}');
    } catch (e) {
      AppLogger.w('[AuthApiService] Update profile unexpected error: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete(
        ApiConfig.me,
        options: authOptions(),
      );

      await LocalDbService.instance.clearAllData();
      await PendingDeletionsStore.instance.clear();
      await handleSessionExpired();
    } catch (e) {
      AppLogger.e('[AuthApiService] Delete account error', e);
      rethrow;
    }
  }

  Future<LogoutResponseModel> logout() async {
    final token = _token;
    if (token == null) {
      AppLogger.w('[AuthApiService] Logout attempted without token');
      return LogoutResponseModel(status: 'error', message: 'Не авторизован');
    }

    try {
      final response = await _dio.post(
        ApiConfig.logout,
        options: authOptions(token),
      );

      final logoutResponse = LogoutResponseModel.fromJson(response.data);
      AppLogger.i('[AuthApiService] Logout success: ${logoutResponse.message}');
      return logoutResponse;
    } on DioException catch (e) {
      AppLogger.w(
          '[AuthApiService] Logout error: ${e.response?.data ?? e.message}');
      rethrow;
    } finally {
      await clearAllUserData();
    }
  }

  Future<void> performLogout() async {
    await clearAllUserData();
    _authStream.add(false);
  }

  Future<String?> performTokenRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final currentRefresh =
          _refreshToken ?? await _storage.read(key: 'refresh_token');
      if (currentRefresh == null || currentRefresh.isEmpty) {
        AppLogger.w('[AuthApiService] No refresh token available');
        await handleSessionExpired();
        completer.complete(null);
        return null;
      }

      AppLogger.i(
          '[AuthApiService] Token expired (401), attempting refresh...');

      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refresh_token': currentRefresh},
      );

      final resData = response.data is Map
          ? (response.data['data'] is Map
              ? response.data['data'] as Map<String, dynamic>
              : response.data as Map<String, dynamic>)
          : <String, dynamic>{};

      final newAccess = resData['access_token'] as String?;
      final newRefresh = resData['refresh_token'] as String? ?? currentRefresh;

      if (newAccess != null && newAccess.isNotEmpty) {
        await setTokens(newAccess, newRefresh);
        AppLogger.i('[AuthApiService] Token refreshed successfully');
        completer.complete(newAccess);
        return newAccess;
      } else {
        throw Exception('Empty access token returned on refresh');
      }
    } catch (e) {
      AppLogger.e('[AuthApiService] Token refresh failed', e);
      completer.complete(null);

      bool isNetworkError = false;
      if (e is DioException) {
        isNetworkError = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown;
      }
      if (!isNetworkError) {
        await handleSessionExpired();
      }
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> refreshAuthTokens() async {
    final newAccess = await performTokenRefresh();
    return newAccess != null && newAccess.isNotEmpty;
  }

  void dispose() {
    _authStream.close();
  }
}
