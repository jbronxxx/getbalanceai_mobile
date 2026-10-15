import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/legal_links.dart';
import '../../utils/utils.dart';
import '../app_alerts.dart';
import '../../theme/app_colors.dart';

/// Открывает URL во внешнем браузере; возвращает `false`, если открыть не удалось.
Future<bool> openExternalUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Карточка раздела «Данные» в профиле: ссылка на справочную страницу
/// об удалении аккаунта и данных (публичная страница бэкенда).
class ProfileDataCard extends StatelessWidget {
  final Future<bool> Function(Uri uri) launcher;

  const ProfileDataCard({super.key, this.launcher = openExternalUrl});

  Future<void> _openDeletionInfo(BuildContext context) async {
    final l10n = context.l10n;
    var opened = false;
    try {
      final languageCode = Localizations.localeOf(context).languageCode;
      opened =
          await launcher(LegalLinks.url(LegalPage.deleteAccount, languageCode));
    } catch (e, stack) {
      AppLogger.e('Не удалось открыть страницу удаления аккаунта', e, stack);
    }
    if (!opened && context.mounted) {
      AppAlerts.error(context, l10n.open_link_error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    final glassBg = AppColors.of(context).cardGlassBackground;
    final glassBorder = AppColors.of(context).cardBorder;

    return Container(
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glassBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ListTile(
          leading: Icon(Icons.privacy_tip_outlined,
              color: AppColors.of(context).accentText),
          title: Text(
            l10n.delete_account_info_title,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            l10n.delete_account_info_subtitle,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          trailing:
              Icon(Icons.open_in_new, size: 20, color: colorScheme.outline),
          onTap: () => _openDeletionInfo(context),
        ),
      ),
    );
  }
}
