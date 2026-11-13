import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/legal_links.dart';
import '../utils/utils.dart';
import 'app_alerts.dart';

/// Открывает URL во внешнем браузере; возвращает `false`, если открыть не удалось.
Future<bool> openExternalUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Открывает публичную страницу [page] на языке интерфейса; если открыть
/// не удалось — сообщение об ошибке.
Future<void> openLegalPage(
  BuildContext context,
  LegalPage page, {
  Future<bool> Function(Uri uri) launcher = openExternalUrl,
}) async {
  final l10n = context.l10n;
  var opened = false;
  try {
    final languageCode = Localizations.localeOf(context).languageCode;
    opened = await launcher(LegalLinks.url(page, languageCode));
  } catch (e, stack) {
    AppLogger.e('Не удалось открыть страницу /${page.slug}', e, stack);
  }
  if (!opened && context.mounted) {
    AppAlerts.error(context, l10n.open_link_error);
  }
}
