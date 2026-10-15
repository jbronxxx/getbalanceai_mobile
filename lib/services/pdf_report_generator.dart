import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../utils/utils.dart';

/// Формирует PDF-отчёт: сводка, расходы по категориям, выполнение лимитов
/// и таблица операций.
///
/// Шрифты передаются снаружи (из ассетов) — встроенные шрифты PDF не
/// содержат кириллицу. Суммы выводятся с кодом валюты, а не символом: так
/// отчёт не зависит от наличия глифа (например, ₸) в шрифте.
class PdfReportGenerator {
  /// Максимум страниц: значение по умолчанию (20) обрывает выгрузку
  /// за год с большим числом операций.
  static const _maxPages = 5000;

  static Future<Uint8List> generate(
    ReportData data,
    AppLocalizations l10n, {
    required String languageCode,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) async {
    final code = data.currency.code;
    String money(double v, Currency c, {bool showSign = false}) =>
        CurrencyFormatter.format(
          v,
          showSymbol: false,
          showSign: showSign,
          currency: c,
          locale: languageCode,
        );
    String baseMoney(double v, {bool showSign = false}) =>
        '${money(v, data.currency, showSign: showSign)} $code';

    final titleStyle = pw.TextStyle(font: boldFont, fontSize: 20);
    final sectionStyle = pw.TextStyle(font: boldFont, fontSize: 13);
    const mutedStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
    final headerStyle = pw.TextStyle(font: boldFont, fontSize: 9);
    const cellStyle = pw.TextStyle(fontSize: 9);
    const headerDecoration = pw.BoxDecoration(color: PdfColors.grey200);

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(title, style: sectionStyle),
        );

    pw.Widget summaryRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: cellStyle),
              pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 10)),
            ],
          ),
        );

    final totalExpense = data.totalExpense;
    final categories = data.categoryExpenses;

    final doc = pw.Document(title: l10n.report_title, creator: 'GetBalance AI');
    doc.addPage(
      pw.MultiPage(
        maxPages: _maxPages,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: mutedStyle,
          ),
        ),
        build: (context) => [
          pw.Text(l10n.report_title, style: titleStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_formatDate(data.period.start)} — ${_formatDate(data.period.end)}'
            ' · $code',
            style: mutedStyle,
          ),
          pw.Text(
            '${l10n.report_generated_at}: ${_formatDate(data.generatedAt)}',
            style: mutedStyle,
          ),
          section(l10n.report_summary),
          summaryRow(l10n.report_total_income, baseMoney(data.totalIncome)),
          summaryRow(l10n.report_total_expense, baseMoney(totalExpense)),
          summaryRow(
            l10n.report_period_result,
            baseMoney(data.balance, showSign: true),
          ),
          if (categories.isNotEmpty) ...[
            section(l10n.report_by_category),
            pw.TableHelper.fromTextArray(
              headers: [l10n.report_col_category, code, l10n.report_share],
              data: [
                for (final e in categories)
                  [
                    e.key.getLocalizedName(),
                    money(e.value, data.currency),
                    _percent(e.value, totalExpense),
                  ],
              ],
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: headerDecoration,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
            ),
          ],
          if (data.budgetLines.isNotEmpty) ...[
            section(l10n.budgets_title),
            pw.TableHelper.fromTextArray(
              headers: [
                l10n.month_label,
                l10n.report_col_category,
                l10n.report_limit,
                l10n.report_spent,
                '%',
              ],
              data: [
                for (final b in data.budgetLines)
                  [
                    '${LanguageManager.getMonthName(b.month)} ${b.year}',
                    b.category.getLocalizedName(),
                    money(b.limit, data.currency),
                    money(b.spent, data.currency),
                    _percent(b.spent, b.limit),
                  ],
              ],
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: headerDecoration,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
            ),
          ],
          if (data.transactions.isNotEmpty) ...[
            section(l10n.report_transactions),
            pw.TableHelper.fromTextArray(
              headers: [
                l10n.report_col_date,
                l10n.report_col_type,
                l10n.report_col_category,
                l10n.report_col_description,
                l10n.report_col_amount,
                l10n.report_col_amount_base(code),
              ],
              data: [
                for (final t in data.transactions)
                  [
                    _formatDate(t.date),
                    t.type == TransactionType.income
                        ? l10n.type_income
                        : l10n.type_expense,
                    t.category.getLocalizedName(),
                    t.description,
                    '${money(t.amount, t.currency)} ${t.currency.code}',
                    money(t.baseAmount, data.currency),
                  ],
              ],
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: headerDecoration,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  static String _percent(double part, double whole) {
    if (whole <= 0) return '—';
    return '${(part / whole * 100).round()}%';
  }
}
