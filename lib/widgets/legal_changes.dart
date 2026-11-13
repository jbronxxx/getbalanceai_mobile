import 'package:flutter/material.dart';
import '../config/legal_links.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/utils.dart';
import 'legal_page_link.dart';
import 'whole_words_text.dart';

/// Новая версия документа: дата вступления в силу, «Что изменилось» и ссылка
/// на полный текст. Общий блок экрана новой версии условий и шторки
/// о новой политике.
class LegalChanges extends StatelessWidget {
  final LegalDocumentInfo info;
  final LegalPage page;

  /// Подзаголовок вместо «Что изменилось» — когда на экране два документа.
  final String? heading;

  const LegalChanges({
    super.key,
    required this.info,
    required this.page,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final bodyStyle =
        textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WholeWordsText(
          heading ?? context.l10n.legal_whats_changed,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        WholeWordsText(
          context.l10n.legal_effective_date(
              LanguageManager.formatDayMonthYear(info.effectiveDate)),
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final change in info.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: bodyStyle),
                Expanded(child: WholeWordsText(change, style: bodyStyle)),
              ],
            ),
          ),
        TextButton(
          key: ValueKey('legal_read_full_${page.slug}'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => openLegalPage(context, page),
          child: WholeWordsText(
            context.l10n.legal_read_full,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.of(context).accentText,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
