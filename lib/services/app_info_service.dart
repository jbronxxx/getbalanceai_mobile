import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/language_manager.dart';
import 'device_capability_service.dart';

/// Сервис для получения и кеширования информации о приложении.
class AppInfoService {
  AppInfoService._internal();

  static final AppInfoService instance = AppInfoService._internal();

  PackageInfo? _cachedPackageInfo;

  /// Возвращает кешированный экземпляр [PackageInfo] или запрашивает его у платформы.
  Future<PackageInfo> getPackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    return _cachedPackageInfo!;
  }

  /// Возвращает форматированную строку версии и номера сборки (например, '1.0.0+1').
  Future<String> getVersionString() async {
    final info = await getPackageInfo();
    return '${info.version}+${info.buildNumber}';
  }

  /// Возвращает название приложения.
  Future<String> getAppName() async {
    final info = await getPackageInfo();
    return info.appName;
  }

  /// Возвращает идентификатор пакета приложения.
  Future<String> getPackageName() async {
    final info = await getPackageInfo();
    return info.packageName;
  }

  /// Заголовки о клиенте для запросов к бэкенду (OBS-02): журнал запросов
  /// сервера пишет их отдельными полями — версия приложения, ОС, модель,
  /// язык интерфейса. Без постоянных идентификаторов устройства и личных
  /// данных. До [init] и до `DeviceCapabilityService.init` недостающие
  /// значения просто не отправляются.
  Map<String, String> get clientHeaders {
    final info = _cachedPackageInfo;
    final model = DeviceCapabilityService.instance.deviceModel;
    return {
      if (info != null)
        appVersionHeader: _headerValue('${info.version}+${info.buildNumber}'),
      platformHeader: _headerValue(_platform()),
      if (model != null) deviceModelHeader: _headerValue(model),
      appLanguageHeader: LanguageManager.code,
    };
  }

  static const appVersionHeader = 'X-App-Version';
  static const platformHeader = 'X-Platform';
  static const deviceModelHeader = 'X-Device-Model';
  static const appLanguageHeader = 'X-App-Language';

  /// Предел длины значения заголовка; бэкенд обрезает так же.
  static const _maxHeaderLength = 64;

  /// `Android 15; API 35` на Android, имя платформы на остальных.
  static String _platform() {
    final device = DeviceCapabilityService.instance;
    if (!device.isAndroid) return defaultTargetPlatform.name;
    return [
      'Android ${device.androidRelease ?? ''}'.trim(),
      if (device.androidSdkVersion != null) 'API ${device.androidSdkVersion}',
    ].join('; ');
  }

  /// Значение заголовка — только печатные ASCII-символы (иначе HTTP-клиент
  /// откажет в запросе) и не длиннее [_maxHeaderLength].
  static String _headerValue(String value) {
    final printable = value.replaceAll(RegExp(r'[^\x20-\x7E]'), '?').trim();
    return printable.length <= _maxHeaderLength
        ? printable
        : printable.substring(0, _maxHeaderLength);
  }

  /// Выполняет предзагрузку информации о приложении в память.
  Future<void> init() async {
    await getPackageInfo();
  }

  /// Сбрасывает закешированные данные.
  @visibleForTesting
  void reset() {
    _cachedPackageInfo = null;
  }

  /// Задает мок-объект информации о приложении для тестирования.
  @visibleForTesting
  void setMockPackageInfo(PackageInfo info) {
    _cachedPackageInfo = info;
  }
}
