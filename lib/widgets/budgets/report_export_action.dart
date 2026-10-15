import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import 'report_export_sheet.dart';

/// Кнопка «Отчёт» в шапке вкладки «Бюджет» — в том же стиле, что «Войти» на
/// дашборде; открывает выгрузку отчёта в CSV/PDF за выбранный месяц.
class ReportExportAction extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;

  const ReportExportAction({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: context.l10n.report_export_title,
      child: TextButton.icon(
        onPressed: () => ReportExportSheet.show(
          context,
          month: selectedMonth,
          year: selectedYear,
        ),
        icon: const Icon(Icons.file_download_outlined, size: 18),
        label: Text(
          context.l10n.report_btn_short,
          maxLines: 1,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
