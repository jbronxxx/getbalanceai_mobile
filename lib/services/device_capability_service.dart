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

  /// Канал к `MainActivity`: уровень API берётся из `Build.VERSION.SDK_INT`.
  @visibleForTesting
  static const channel = MethodChannel('com.getbalanceai.mobile/device');

  int? _androidSdk;
  bool? _mockBlurSupported;

  /// Проверяет, является ли текущая платформа Android (безопасно для Web).
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Уровень Android API (SDK_INT); `null` — не Android, [init] ещё не
  /// вызывался или версию не удалось получить.
  int? get androidSdkVersion => _androidSdk;

  /// Запрашивает уровень API у платформы. Вызывается один раз при старте,
  /// до первого кадра: [isBlurSupported] читается синхронно при отрисовке.
  /// Сбой канала не мешает запуску — размытие тогда остаётся включённым.
  Future<void> init() async {
    if (!isAndroid) return;
    try {
      _androidSdk = await channel.invokeMethod<int>('androidSdkInt');
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

  /// Устанавливает принудительное значение поддержки размытия для тестов.
  @visibleForTesting
  void setMockBlurSupported(bool? value) {
    _mockBlurSupported = value;
  }

  /// Сбрасывает закешированные значения (для тестов).
  @visibleForTesting
  void reset() {
    _androidSdk = null;
    _mockBlurSupported = null;
  }
}
