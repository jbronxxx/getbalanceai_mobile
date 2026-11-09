import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import '../utils/app_logger.dart';
import 'preferences_service.dart';

/// Итог проверки владельца телефона.
enum AppLockResult {
  success,

  /// Отменено или не распознано — можно повторить.
  failed,

  /// На телефоне нет блокировки экрана (PIN, графического ключа, отпечатка).
  unavailable,

  /// Телефон временно не принимает попытки — слишком много неудачных.
  lockedOut,
}

/// SEC-08: вход по блокировке телефона — отпечаток, лицо или PIN/графический
/// ключ устройства (своего PIN у приложения нет). Включается в «Профиле»,
/// по умолчанию выключен.
///
/// Приложение запирается при запуске и при возврате, если оно пробыло в фоне
/// не меньше [relockAfter]: короткий выход в «Поделиться», выбор файла или
/// вход через Google проверку не повторяет.
class AppLockService with WidgetsBindingObserver {
  AppLockService({
    LocalAuthentication? auth,
    PreferencesService? preferences,
    DateTime Function()? clock,
  })  : _auth = auth ?? LocalAuthentication(),
        _preferences = preferences ?? PreferencesService.instance,
        _clock = clock ?? DateTime.now;

  static AppLockService instance = AppLockService();

  static const relockAfter = Duration(minutes: 1);

  final LocalAuthentication _auth;
  final PreferencesService _preferences;
  final DateTime Function() _clock;

  /// Блокировка включена в «Профиле».
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  /// Сейчас приложение закрыто экраном блокировки.
  final ValueNotifier<bool> locked = ValueNotifier(false);

  bool _observing = false;
  bool _authenticating = false;
  DateTime? _hiddenAt;

  /// Вызывается при старте до `runApp`: при включённой блокировке приложение
  /// открывается запертым. Наблюдатель жизненного цикла регистрируется раньше
  /// навигатора — так «Назад» на экране блокировки не закрывает шторки под
  /// ним (см. [didPopRoute]).
  Future<void> init() async {
    enabled.value = await _preferences.isAppLockEnabled();
    locked.value = enabled.value;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  /// Есть ли на телефоне блокировка экрана, которой можно подтвердить вход.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      AppLogger.w('[AppLock] isDeviceSupported failed', e);
      return false;
    }
  }

  /// Системное окно отпечатка/PIN. [title] — заголовок окна на Android,
  /// [reason] — текст под ним (и на iOS). Отмена — [AppLockResult.failed].
  Future<AppLockResult> authenticate({
    required String title,
    required String reason,
  }) async {
    if (_authenticating) return AppLockResult.failed;
    _authenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        // Без лишнего «Подтвердить» после распознавания лица: открыть
        // приложение — не платёж.
        sensitiveTransaction: false,
        // Подзаголовок по умолчанию — английский «Verify identity»; пустой
        // система не показывает, текст проверки — в [reason].
        authMessages: [AndroidAuthMessages(signInTitle: title, signInHint: '')],
      );
      if (!ok) return AppLockResult.failed;
      // Окно PIN — отдельный экран: приложение уходило в фон, но это не
      // повод запирать его снова при возврате.
      _hiddenAt = null;
      return AppLockResult.success;
    } on LocalAuthException catch (e) {
      AppLogger.w('[AppLock] authenticate: ${e.code}', e);
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware =>
          AppLockResult.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          AppLockResult.lockedOut,
        _ => AppLockResult.failed,
      };
    } on PlatformException catch (e) {
      AppLogger.w('[AppLock] authenticate failed', e);
      return AppLockResult.failed;
    } finally {
      _authenticating = false;
    }
  }

  /// Снимает блокировку после проверки. Если блокировку экрана с телефона
  /// убрали, вход по ней невозможен — она выключается и в приложении: снять
  /// блокировку телефона без его PIN нельзя, так что обхода здесь нет.
  Future<AppLockResult> unlock({
    required String title,
    required String reason,
  }) async {
    final result = await authenticate(title: title, reason: reason);
    if (result == AppLockResult.unavailable) {
      await setEnabled(false);
    }
    if (result == AppLockResult.success ||
        result == AppLockResult.unavailable) {
      locked.value = false;
    }
    return result;
  }

  /// Включает или выключает блокировку. Подтверждение отпечатком/PIN
  /// запрашивает вызывающий («Профиль»).
  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    if (!value) locked.value = false;
    await _preferences.setAppLockEnabled(value);
  }

  void _lock() {
    locked.value = true;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled.value || _authenticating) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _hiddenAt ??= _clock();
      case AppLifecycleState.resumed:
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (hiddenAt != null && _clock().difference(hiddenAt) >= relockAfter) {
          _lock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// «Назад» на экране блокировки сворачивает приложение, а не закрывает
  /// шторки и экраны под ним.
  @override
  Future<bool> didPopRoute() async {
    if (!locked.value) return false;
    await SystemNavigator.pop();
    return true;
  }
}
