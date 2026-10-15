import 'environment.dart';

/// Публичные страницы бэкенда, на которые ссылается приложение.
enum LegalPage {
  terms('terms'),
  privacy('privacy'),
  deleteAccount('delete-account');

  final String slug;

  const LegalPage(this.slug);
}

/// Ссылки на публичные страницы бэкенда (условия, политика, удаление аккаунта).
///
/// Адрес берется из `baseUrl` текущего окружения без пути `/api/v1`, поэтому
/// в debug-сборке с локальным бэкендом страницы открываются с него же,
/// а release всегда ведет на прод.
class LegalLinks {
  const LegalLinks._();

  /// URL страницы [page] на языке [languageCode] (`ru`, `en`, `uz`, `kk`).
  /// [baseUrl] нужен только для тестов; по умолчанию — `EnvironmentConfig.baseUrl`.
  static Uri url(LegalPage page, String languageCode, {String? baseUrl}) {
    final base = Uri.parse(baseUrl ?? EnvironmentConfig.baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/${page.slug}',
      queryParameters: {'lang': languageCode},
    );
  }
}
