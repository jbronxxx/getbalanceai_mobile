import 'package:flutter/material.dart';
import '../../config/legal_links.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';
import '../legal_page_link.dart';
import '../whole_words_text.dart';

/// Карточка раздела «Документы» в профиле (видна и гостю): условия
/// использования, политика конфиденциальности и справка об удалении аккаунта
/// и данных — публичные страницы бэкенда на языке интерфейса.
class ProfileLegalCard extends StatelessWidget {
  final Future<bool> Function(Uri uri) launcher;

  const ProfileLegalCard({super.key, this.launcher = openExternalUrl});

  void _open(BuildContext context, LegalPage page) =>
      openLegalPage(context, page, launcher: launcher);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final divider = Divider(height: 1, thickness: 1, color: colors.cardDivider);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardGlassBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            _LegalLinkTile(
              title: l10n.terms_of_use_title,
              onTap: () => _open(context, LegalPage.terms),
            ),
            divider,
            _LegalLinkTile(
              title: l10n.privacy_policy_title,
              onTap: () => _open(context, LegalPage.privacy),
            ),
            divider,
            _LegalLinkTile(
              title: l10n.delete_account_info_title,
              subtitle: l10n.delete_account_info_subtitle,
              onTap: () => _open(context, LegalPage.deleteAccount),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пункт карточки «Документы»: название, необязательное пояснение и знак
/// внешней ссылки — страница откроется в браузере.
class _LegalLinkTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _LegalLinkTile({
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final subtitle = this.subtitle;

    return ListTile(
      title: WholeWordsText(
        title,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : WholeWordsText(
              subtitle,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
      trailing: Icon(Icons.open_in_new, size: 20, color: colorScheme.outline),
      onTap: onTap,
    );
  }
}
