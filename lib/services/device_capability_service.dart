import 'dart:io' as io;
import 'package:flutter/foundation.dart';

/// Сервис определения аппаратных и платформенных возможностей устройства.
///
/// Используется для оптимизации отрисовки тяжелых графических эффектов (размытие,
/// BackdropFilter, сложные анимации) на маломощных устройствах и старых версиях Android.
class DeviceCapabilityService {
  DeviceCapabilityService._internal();

  static final DeviceCapabilityService instance =
      DeviceCapabilityService._internal();

  int? _cachedAndroidSdk;
  bool? _mockBlurSupported;

  /// Проверяет, является ли текущая платформа Android (безопасно для Web).
  bool get isAndroid => !kIsWeb && io.Platform.isAndroid;

  /// Возвращает уровень Android API (SDK_INT) или null, если платформа не Android
  /// либо версию не удалось определить.
  int? get androidSdkVersion {
    if (_cachedAndroidSdk != null) return _cachedAndroidSdk;
    if (!isAndroid) return null;

    try {
      final versionStr = io.Platform.operatingSystemVersion;
      final apiMatch =
          RegExp(r'API\s*(\d+)', caseSensitive: false).firstMatch(versionStr);
      if (apiMatch != null) {
        _cachedAndroidSdk = int.tryParse(apiMatch.group(1)!);
        return _cachedAndroidSdk;
      }

      final androidMatch = RegExp(r'Android\s*(\d+)', caseSensitive: false)
          .firstMatch(versionStr);
      if (androidMatch != null) {
        final version = int.tryParse(androidMatch.group(1)!);
        if (version != null) {
          // Android 10 = API 29, 11 = 30, 12 = 31, 13 = 33, 14 = 34
          _cachedAndroidSdk = version >= 10 ? version + 19 : version;
          return _cachedAndroidSdk;
        }
      }
    } catch (_) {}

    return null;
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
    _cachedAndroidSdk = null;
    _mockBlurSupported = null;
  }
}
