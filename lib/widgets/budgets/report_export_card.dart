import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import 'report_export_sheet.dart';

/// Карточка на экране «Финансы»: открывает форму выгрузки отчёта в CSV/PDF.
class ReportExportCard extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;

  const ReportExportCard({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ListTile(
          leading:
              Icon(Icons.file_download_outlined, color: colorScheme.primary),
          title: Text(
            l10n.report_export_title,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            l10n.report_export_subtitle,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          trailing: Icon(Icons.chevron_right, color: colorScheme.outline),
          onTap: () => ReportExportSheet.show(
            context,
            month: selectedMonth,
            year: selectedYear,
          ),
        ),
      ),
    );
  }
}
