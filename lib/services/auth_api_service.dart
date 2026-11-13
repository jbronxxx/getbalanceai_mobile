import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';
import '../config/secure_storage_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';
import 'api_service.dart';

/// Сервис аутентификации, сессий и управления токенами доступа.
class AuthApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final StreamController<bool> _authStream = StreamController.broadcast();

  /// Пара токенов хранится одним ключом: запись атомарна, и сбой между
  /// записями не оставит новый access со старым refresh. Старый refresh
  /// сервер принимает повторно только 30 секунд после ротации, позже
  /// считает украденным и отзывает все сессии пользователя.
  static const sessionStorageKey = 'auth_session';

  /// Ключи, в которых токены хранились до [sessionStorageKey].
  static const _legacyAccessKey = 'auth_token';
  static const _legacyRefreshKey = 'refresh_token';

  /// Повтор с тем же refresh-токеном должен уложиться в окно, в котором
  /// сервер заменяет недошедшую пару новой (30 с): таймаут ответа
  /// и пауза перед повтором с запасом меньше окна.
  static const _refreshTimeout = Duration(seconds: 15);
  static const _refreshRetryDelay = Duration(seconds: 1);

  String? _token;
  String? _refreshToken;
  Future<String?>? _refreshInFlight;

  /// Растёт при каждой очистке сессии. Refresh, начатый до выхода, сверяет
  /// эпоху и не записывает новые токены обратно (иначе выход «откатился» бы).
  int _sessionEpoch = 0;

  /// Вызывается при входе, как только известен userId, и до того, как
  /// подписчики [authStream] узнают о входе.
  final Future<void> Function(String userId)? _onSignIn;

  /// Статус соглашения и политики из профиля; `null` — сессия очищена.
  final void Function(LegalStatus? status)? _onLegalStatus;

  String? _userId;
  String? _userName;
  String? _email;
  String? _avatarUrl;

  AuthApiService({
    required Dio dio,
    FlutterSecureStorage storage = appSecureStorage,
    Future<void> Function(String userId)? onSignIn,
    void Function(LegalStatus? status)? onLegalStatus,
  })  : _dio = dio,
        _storage = storage,
        _onSignIn = onSignIn,
        _onLegalStatus = onLegalStatus;

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

  /// Восстанавливает сессию при старте. [stored] — содержимое хранилища,
  /// уже прочитанное одним `readAll()` (каждое отдельное чтение — вызов
  /// Keystore/Keychain); без него хранилище читается здесь.
  Future<void> init([Map<String, String>? stored]) async {
    stored ??= await _storage.readAll();
    await _restoreTokens(stored);
    _userId = stored['auth_user_id'];
    _userName = stored['auth_user'];
    _email = stored['auth_email'];
    _avatarUrl = stored['auth_avatar_url'];
  }

  Future<void> setTokens(String? token, String? refresh) async {
    _token = token;
    _refreshToken = refresh;

    if (token != null) {
      await _writeTokens(token, refresh);
      final extracted = _extractUserIdFromToken(token);
      if (extracted != null && _userId == null) {
        await setUserId(extracted);
      }
    } else {
      await _deleteTokens();
      await setUserId(null);
    }
  }

  Future<void> _restoreTokens(Map<String, String> stored) async {
    final raw = stored[sessionStorageKey];
    if (raw != null) {
      try {
        final session = jsonDecode(raw) as Map<String, dynamic>;
        _token = session['access_token'] as String?;
        _refreshToken = session['refresh_token'] as String?;
      } catch (e) {
        AppLogger.w('[AuthApiService] Stored session is unreadable: $e');
      }
      return;
    }

    // Установка, обновлённая с версии, где токены лежали в двух ключах
    final token = stored[_legacyAccessKey];
    if (token == null) return;
    _token = token;
    _refreshToken = stored[_legacyRefreshKey];
    await _writeTokens(token, _refreshToken);
    await _deleteLegacyTokens();
  }

  Future<void> _writeTokens(String token, String? refresh) async {
    await _storage.write(
      key: sessionStorageKey,
      value: jsonEncode({'access_token': token, 'refresh_token': refresh}),
    );
  }

  Future<void> _deleteTokens() async {
    await _storage.delete(key: sessionStorageKey);
    await _deleteLegacyTokens();
  }

  Future<void> _deleteLegacyTokens() async {
    await _storage.delete(key: _legacyAccessKey);
    await _storage.delete(key: _legacyRefreshKey);
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
    final oldUrl = _avatarUrl;
    _avatarUrl = avatarUrl;
    if (avatarUrl != null) {
      await _storage.write(key: 'auth_avatar_url', value: avatarUrl);
    } else {
      await _storage.delete(key: 'auth_avatar_url');
    }
    if (oldUrl != null && oldUrl != avatarUrl) {
      try {
        PaintingBinding.instance.imageCache.evict(NetworkImage(oldUrl));
      } catch (_) {}
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
    _sessionEpoch++;
    // Сначала память: запросы, начатые во время очистки хранилища, уже не
    // должны получить токен вышедшего пользователя.
    _token = null;
    _refreshToken = null;
    _userId = null;
    _userName = null;
    _email = null;
    _avatarUrl = null;
    _onLegalStatus?.call(null);

    try {
      await _deleteTokens();
      await _storage.delete(key: 'auth_user_id');
      await _storage.delete(key: 'auth_user');
      await _storage.delete(key: 'auth_email');
      await _storage.delete(key: 'auth_avatar_url');
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
  }

  Future<void> handleSessionExpired() async {
    await clearAllUserData();
    _authStream.add(false);
  }

  Future<void> loginWithGoogle(
    String idToken, {
    String? avatarUrl,
    String? name,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id_token': idToken,
        // Экран входа не даёт войти без отметки о принятии документов
        'accept_legal': true,
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

      await _handleLoginResponse(response.data);
    } on DioException catch (e) {
      AppLogger.e(
          '[AuthApiService] Google login error: ${e.response?.data ?? e.message}',
          e);
      rethrow;
    }
  }

  Future<void> loginWithApple(String identityToken) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginApple,
        data: {'identity_token': identityToken, 'accept_legal': true},
      );

      await _handleLoginResponse(response.data);
    } on DioException catch (e) {
      AppLogger.e(
          '[AuthApiService] Apple login error: ${e.response?.data ?? e.message}',
          e);
      rethrow;
    }
  }

  Future<void> _handleLoginResponse(dynamic responseData) async {
    final data = responseData['data'];
    final token = data?['access_token'] as String?;
    final refreshToken = data?['refresh_token'] as String?;

    if (token == null || refreshToken == null) {
      throw Exception('Сервер не вернул токены');
    }

    await setTokens(token, refreshToken);

    AuthMeResponseModel? profile;
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      try {
        profile = AuthMeResponseModel.fromJson({'data': user});
        await setUserId(profile.id);
      } catch (e) {
        AppLogger.w('[AuthApiService] Token profile parse error: $e');
        profile = null;
      }
    }

    // userId есть уже после setTokens (из JWT): данные на устройстве
    // проверяются до того, как экраны узнают о входе.
    final userId = _userId;
    if (userId != null) await _onSignIn?.call(userId);

    var profileApplied = false;
    if (profile != null) {
      try {
        await _applyProfile(profile);
        profileApplied = true;
      } catch (e) {
        AppLogger.w('[AuthApiService] Token profile apply error: $e');
      }
    }
    if (!profileApplied) await _fetchAndSaveUserProfile();

    _authStream.add(true);
  }

  Future<void> _applyProfile(AuthMeResponseModel profile) async {
    await setUserId(profile.id);
    await setUserName(profile.userName);
    await setUserEmail(profile.userEmail);
    await setAvatarUrl(profile.avatarUrl);
    final legal = profile.legal;
    if (legal != null) _onLegalStatus?.call(legal);
    final baseCurrency = profile.baseCurrency;
    if (baseCurrency != null) {
      final currency =
          Currency.fromCode(baseCurrency) ?? CurrencyFormatter.currentCurrency;
      await CurrencyFormatter.setCurrency(currency);
    }
    AppLogger.i('[AuthApiService] Profile updated for: ${profile.userName}');
  }

  /// Перечитывает профиль с сервера (при запуске — чтобы узнать о новой
  /// версии соглашения). Ошибки только пишутся в журнал.
  Future<void> refreshProfile() async {
    if (isAuthenticated) await _fetchAndSaveUserProfile();
  }

  Future<void> _fetchAndSaveUserProfile() async {
    try {
      final response = await _dio.get(
        ApiConfig.me,
        options: authOptions(),
      );
      await _applyProfile(AuthMeResponseModel.fromJson(response.data));
    } on DioException catch (e) {
      AppLogger.w(
          '[AuthApiService] Fetch profile error: ${e.response?.data ?? e.message}');
    } catch (e) {
      AppLogger.w('[AuthApiService] Profile parse error: $e');
    }
  }

  /// Длина имени — как у колонки `users.name` на сервере.
  static const userNameMaxLength = 100;

  /// Меняет имя на сервере и на устройстве. Ошибка сервера или сети
  /// пробрасывается: имя на устройстве меняется только после ответа сервера.
  Future<void> updateUserName(String name) async {
    final response = await _dio.patch(
      ApiConfig.me,
      data: {'name': name.trim()},
      options: authOptions(),
    );
    final data = response.data;
    final saved = data is Map ? data['data'] : null;
    final savedName = saved is Map ? saved['name'] : null;
    await setUserName(savedName is String ? savedName : name.trim());
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

  /// Удаляет аккаунт на сервере и очищает сессию. Локальные данные стирает
  /// и о выходе сообщает [ApiService.deleteAccount].
  Future<void> deleteAccount() async {
    try {
      await _dio.delete(
        ApiConfig.me,
        options: authOptions(),
      );

      await clearAllUserData();
    } catch (e) {
      AppLogger.e('[AuthApiService] Delete account error', e);
      rethrow;
    }
  }

  /// Отзывает сессию на сервере и очищает её на устройстве. Ошибка сервера
  /// пробрасывается, но сессия очищается в любом случае.
  Future<void> logout() async {
    final token = _token;
    if (token == null) {
      AppLogger.w('[AuthApiService] Logout attempted without token');
      return;
    }

    try {
      await _dio.post(
        ApiConfig.logout,
        options: authOptions(token),
      );
      AppLogger.i('[AuthApiService] Logout success');
    } on DioException catch (e) {
      AppLogger.w(
          '[AuthApiService] Logout error: ${e.response?.data ?? e.message}');
      rethrow;
    } finally {
      await clearAllUserData();
    }
  }

  /// Сообщает подписчикам [authStream], что сессия завершена.
  void notifyLoggedOut() => _authStream.add(false);

  /// Обновляет пару токенов по refresh-токену; параллельные вызовы ждут
  /// один запрос.
  ///
  /// `null` — сессии больше нет: сервер отклонил refresh-токен (401), токена
  /// нет или пользователь вышел, пока шёл запрос. Временный сбой (сеть, 429,
  /// 5xx) пробрасывается как [DioException]: токены сохраняются, а вызывающий
  /// показывает настоящую причину вместо «Сессия истекла».
  Future<String?> performTokenRefresh() => _refreshInFlight ??=
      _refresh().whenComplete(() => _refreshInFlight = null);

  Future<String?> _refresh() async {
    final epoch = _sessionEpoch;
    final currentRefresh = _refreshToken;
    if (currentRefresh == null || currentRefresh.isEmpty) {
      AppLogger.w('[AuthApiService] No refresh token available');
      await handleSessionExpired();
      return null;
    }

    AppLogger.i('[AuthApiService] Token expired (401), attempting refresh...');

    final Response<dynamic> response;
    try {
      response = await _postRefresh(currentRefresh, epoch);
    } on DioException catch (e) {
      if (epoch != _sessionEpoch) return null;
      // Сессию завершает только 401: сервер отклонил refresh-токен. Сеть, 429
      // и 5xx (например, 503 при сбое Redis) — временные сбои: токены
      // сохраняются, запрос можно повторить, пользователь остаётся в аккаунте.
      if (e.response?.statusCode == 401) {
        AppLogger.w('[AuthApiService] Refresh token rejected, session ended');
        await handleSessionExpired();
        return null;
      }
      AppLogger.e('[AuthApiService] Token refresh failed', e);
      rethrow;
    }

    if (epoch != _sessionEpoch) {
      AppLogger.i(
          '[AuthApiService] Session ended during refresh, tokens discarded');
      return null;
    }

    final data = response.data is Map ? response.data['data'] : null;
    final newAccess = data is Map ? data['access_token'] as String? : null;
    if (newAccess == null || newAccess.isEmpty) {
      throw DioException.badResponse(
        statusCode: response.statusCode ?? 200,
        requestOptions: response.requestOptions,
        response: response,
      );
    }
    final newRefresh = data['refresh_token'] as String? ?? currentRefresh;

    await setTokens(newAccess, newRefresh);
    AppLogger.i('[AuthApiService] Token refreshed successfully');
    return newAccess;
  }

  /// Ответ на ротацию мог потеряться (обрыв, таймаут, сбой прокси), когда
  /// сервер уже выдал новую пару и отозвал [refreshToken]. Повтор с тем же
  /// токеном в течение 30 секунд сервер обслуживает как повтор ротации;
  /// позже — отзывает все сессии, поэтому повтор один и сразу.
  Future<Response<dynamic>> _postRefresh(String refreshToken, int epoch) async {
    Future<Response<dynamic>> post() => _dio.post(
          ApiConfig.refreshToken,
          data: {'refresh_token': refreshToken},
          options: Options(
            sendTimeout: _refreshTimeout,
            receiveTimeout: _refreshTimeout,
          ),
        );

    try {
      return await post();
    } on DioException catch (e) {
      if (!_responseMayBeLost(e) || epoch != _sessionEpoch) rethrow;
      AppLogger.w('[AuthApiService] Refresh response lost (${e.type}), '
          'retrying with the same token');
      await Future<void>.delayed(_refreshRetryDelay);
      if (epoch != _sessionEpoch) rethrow;
      return post();
    }
  }

  /// Запрос мог дойти до сервера, а ответ — потеряться. Таймаут соединения
  /// сюда не входит: запрос не ушёл.
  static bool _responseMayBeLost(DioException e) => switch (e.type) {
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError ||
        DioExceptionType.unknown =>
          true,
        DioExceptionType.badResponse =>
          const {502, 504}.contains(e.response?.statusCode),
        _ => false,
      };

  void dispose() {
    _authStream.close();
  }
}
