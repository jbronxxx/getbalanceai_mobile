import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
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
    } else {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
    }
  }

  Future<void> setUserName(String? userName) async {
    if (userName != null) {
      _userName = userName;
      await _storage.write(key: 'auth_user', value: userName);
    }
  }

  Future<void> setAvatarUrl(String? avatarUrl) async {
    _avatarUrl = avatarUrl;
    if (avatarUrl != null) {
      await _storage.write(key: 'auth_avatar_url', value: avatarUrl);
    } else {
      await _storage.delete(key: 'auth_avatar_url');
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
      await _storage.delete(key: 'auth_user');
      await _storage.delete(key: 'auth_email');
      await _storage.delete(key: 'auth_avatar_url');
      await _storage.delete(key: 'transactions_etag');
      await _storage.delete(key: 'budgets_etag');
    } catch (e) {
      AppLogger.w('[AuthApiService] Secure storage clear error: $e');
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      AppLogger.w('[AuthApiService] Google signOut error: $e');
    }

    _token = null;
    _refreshToken = null;
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

  Future<LoginResponseModel> loginWithGoogle(String idToken) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginGoogle,
        data: {'id_token': idToken},
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
    await fetchAndSaveUserProfile();

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
      await setUserName(userProfile.userName);
      await setUserEmail(userProfile.userEmail);
      await setAvatarUrl(userProfile.avatarUrl);
      AppLogger.i(
          '[AuthApiService] Profile updated for: ${userProfile.userName}');
    } on DioException catch (e) {
      AppLogger.w(
          '[AuthApiService] Fetch profile error: ${e.response?.data ?? e.message}');
    } catch (e) {
      AppLogger.w('[AuthApiService] Profile parse error: $e');
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
