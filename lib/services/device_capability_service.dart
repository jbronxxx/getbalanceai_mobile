import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

/// Сервис определения аппаратных и платформенных возможностей устройства.
///
/// Используется для оптимизации отрисовки тяжелых графических эффектов (размытие,
/// BackdropFilter, сложные анимации) на маломощных устройствах и старых версиях Android.
class DeviceCapabilityService {
  DeviceCapabilityService._internal();

  static final DeviceCapabilityService instance =
      DeviceCapabilityService._internal();

  /// Канал к `MainActivity`: уровень API, версия Android, производитель и
  /// модель из `Build`.
  @visibleForTesting
  static const channel = MethodChannel('com.getbalanceai.mobile/device');

  int? _androidSdk;
  String? _androidRelease;
  String? _deviceModel;
  bool? _mockBlurSupported;

  /// Проверяет, является ли текущая платформа Android (безопасно для Web).
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Уровень Android API (SDK_INT); `null` — не Android, [init] ещё не
  /// вызывался или версию не удалось получить.
  int? get androidSdkVersion => _androidSdk;

  /// Версия Android для пользователя (`Build.VERSION.RELEASE`, например `15`).
  String? get androidRelease => _androidRelease;

  /// Производитель и модель (`samsung SM-S921B`); `null` — не Android или
  /// [init] не получил данные.
  String? get deviceModel => _deviceModel;

  /// Запрашивает данные устройства у платформы. Вызывается один раз при
  /// старте, до первого кадра: [isBlurSupported] читается синхронно при
  /// отрисовке. Сбой канала не мешает запуску — размытие тогда остаётся
  /// включённым, а запросы уходят без версии ОС и модели.
  Future<void> init() async {
    if (!isAndroid) return;
    try {
      final info =
          await channel.invokeMapMethod<String, Object?>('deviceInfo') ?? {};
      _androidSdk = info['sdkInt'] as int?;
      _androidRelease = info['release'] as String?;
      _deviceModel = _modelName(
        info['manufacturer'] as String?,
        info['model'] as String?,
      );
    } catch (e) {
      AppLogger.w('[DeviceCapabilityService] Android SDK unavailable: $e');
    }
  }

  /// Проверяет, поддерживается ли аппаратно ускоренное размытие фона ([BackdropFilter]).
  ///
  /// На Android до API 31 (Android 12) системный вызов размытия не имеет прямой аппаратной
  /// акселерации через RenderEffect, что вызывает просадку FPS и задержки скролла.
  bool get isBlurSupported {
    if (_mockBlurSupported != null) return _mockBlurSupported!;

    if (isAndroid) {
      final sdk = androidSdkVersion;
      if (sdk != null && sdk < 31) {
        return false;
      }
    }

    return true;
  }

  /// «Производитель модель»; производитель не повторяется, если модель
  /// с него уже начинается (`Google Pixel 8`, а не `Google Google Pixel 8`).
  static String? _modelName(String? manufacturer, String? model) {
    final maker = manufacturer?.trim() ?? '';
    final name = model?.trim() ?? '';
    if (name.isEmpty) return maker.isEmpty ? null : maker;
    if (maker.isEmpty || name.toLowerCase().startsWith(maker.toLowerCase())) {
      return name;
    }
    return '$maker $name';
  }

  /// Устанавливает принудительное значение поддержки размытия для тестов.
  @visibleForTesting
  void setMockBlurSupported(bool? value) {
    _mockBlurSupported = value;
  }

  /// Сбрасывает закешированные значения (для тестов).
  @visibleForTesting
  void reset() {
    _androidSdk = null;
    _androidRelease = null;
    _deviceModel = null;
    _mockBlurSupported = null;
  }
}
