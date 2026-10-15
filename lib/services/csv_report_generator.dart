import '../models/models.dart';
import '../utils/utils.dart';

/// Формирует CSV-отчёт со списком операций за период.
///
/// Диалект зависит от языка интерфейса: Excel в русской, казахской и
/// узбекской локалях ожидает `;` как разделитель полей и `,` как десятичный
/// знак, в английской — `,` и `.`. Файл в UTF-8 с BOM, иначе Excel ломает
/// кириллицу.
class CsvReportGenerator {
  static const _bom = '﻿';
  static const _lineBreak = '\r\n';

  /// Возвращает содержимое файла (с BOM) для [data] на языке [l10n].
  static String generate(
    ReportData data,
    AppLocalizations l10n, {
    required String languageCode,
  }) {
    final isEn = languageCode.toLowerCase().startsWith('en');
    final delimiter = isEn ? ',' : ';';
    final decimalSeparator = isEn ? '.' : ',';
    final baseCode = data.currency.code;

    String number(double value, int digits) =>
        value.toStringAsFixed(digits).replaceFirst('.', decimalSeparator);

    final buffer = StringBuffer(_bom);
    void writeRow(List<String> cells) {
      buffer
        ..writeAll(cells.map((c) => _escape(c, delimiter)), delimiter)
        ..write(_lineBreak);
    }

    writeRow([
      l10n.report_col_date,
      l10n.report_col_type,
      l10n.report_col_category,
      l10n.report_col_description,
      l10n.report_col_amount,
      l10n.currency,
      l10n.report_col_amount_base(baseCode),
    ]);

    for (final t in data.transactions) {
      writeRow([
        _formatDateTime(t.date),
        t.type == TransactionType.income ? l10n.type_income : l10n.type_expense,
        t.category.getLocalizedName(),
        _neutralizeFormula(t.description),
        number(t.amount, t.currency.defaultDecimalDigits),
        t.currency.code,
        number(t.baseAmount, data.currency.defaultDecimalDigits),
      ]);
    }
    return buffer.toString();
  }

  static String _formatDateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// Защита от CSV-инъекции: ячейка, начинающаяся с символа формулы,
  /// будет выполнена Excel/Sheets, поэтому перед ней ставится апостроф.
  static String _neutralizeFormula(String value) {
    if (value.isEmpty) return value;
    const triggers = {'=', '+', '-', '@', '\t', '\r'};
    return triggers.contains(value[0]) ? "'$value" : value;
  }

  static String _escape(String value, String delimiter) {
    final needsQuotes = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
