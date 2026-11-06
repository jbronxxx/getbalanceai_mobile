import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'csv_report_generator.dart';
import 'pdf_report_generator.dart';
import 'report_data_service.dart';

/// Формирует файл отчёта на устройстве и передаёт его в системное меню
/// «Поделиться» (сохранить в «Файлы», отправить в мессенджер и т.д.).
/// Бэкенд не участвует.
class ReportExportService {
  static const _regularFontAsset = 'assets/google_fonts/Inter-Regular.ttf';
  static const _boldFontAsset = 'assets/google_fonts/Inter-Bold.ttf';
  static const _filePrefix = 'getbalance_report_';

  final ReportDataService _dataService;

  ReportExportService({ReportDataService? dataService})
      : _dataService = dataService ?? ReportDataService();

  /// Собирает отчёт за [period] и доставляет файл способом [mode].
  Future<ReportExportOutcome> export({
    required ReportPeriod period,
    required ReportFormat format,
    required ReportDeliveryMode mode,
    required AppLocalizations l10n,
    required String languageCode,
    Rect? sharePositionOrigin,
  }) async {
    final data = _dataService.build(period);
    if (data.transactions.isEmpty) return ReportExportOutcome.empty;

    final bytes = await render(
      format: format,
      data: data,
      l10n: l10n,
      languageCode: languageCode,
      fonts: format == ReportFormat.pdf
          ? (
              regular: await rootBundle.load(_regularFontAsset),
              bold: await rootBundle.load(_boldFontAsset),
            )
          : null,
    );
    final fileName = _fileName(period, format);

    switch (mode) {
      case ReportDeliveryMode.share:
        final file = await _writeTempFile(bytes, fileName);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: format.mimeType)],
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
        return ReportExportOutcome.completed;
      case ReportDeliveryMode.save:
        // Системный диалог выбора места (SAF на Android, «Файлы» на iOS):
        // разрешения на доступ к хранилищу не нужны. null — отмена.
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.report_export_title,
          fileName: fileName,
          bytes: bytes,
        );
        return savedPath == null
            ? ReportExportOutcome.cancelled
            : ReportExportOutcome.completed;
    }
  }

  /// Строит файл отчёта в фоновом изоляте: на тысячах операций вёрстка PDF
  /// занимает секунды, и в UI-изоляте приложение на это время замирало.
  ///
  /// Статический метод: замыкание, переданное в изолят, не должно захватить
  /// `this` (база данных в другой изолят не передаётся). Шрифты читаются из
  /// ассетов заранее — `rootBundle` работает только в UI-изоляте.
  @visibleForTesting
  static Future<Uint8List> render({
    required ReportFormat format,
    required ReportData data,
    required AppLocalizations l10n,
    required String languageCode,
    ({ByteData regular, ByteData bold})? fonts,
  }) {
    return Isolate.run(() async {
      switch (format) {
        case ReportFormat.csv:
          final csv = CsvReportGenerator.generate(
            data,
            l10n,
            languageCode: languageCode,
          );
          return Uint8List.fromList(utf8.encode(csv));
        case ReportFormat.pdf:
          if (fonts == null) {
            throw ArgumentError.notNull('fonts');
          }
          return PdfReportGenerator.generate(
            data,
            l10n,
            languageCode: languageCode,
            regularFont: pw.Font.ttf(fonts.regular),
            boldFont: pw.Font.ttf(fonts.bold),
          );
      }
    }, debugName: 'report-export');
  }

  Future<File> _writeTempFile(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    await _deleteStaleReports(dir);
    return File(p.join(dir.path, fileName)).writeAsBytes(bytes, flush: true);
  }

  /// Удаляет из кэша последние выгрузки (выход и удаление аккаунта):
  /// в них финансовые данные пользователя.
  static Future<void> deleteCachedReports() async {
    try {
      await _deleteStaleReports(await getTemporaryDirectory());
    } catch (e, stack) {
      AppLogger.w('[ReportExport] Не удалось очистить кэш отчётов', e, stack);
    }
  }

  static String _fileName(ReportPeriod period, ReportFormat format) =>
      '$_filePrefix${_isoDate(period.start)}'
      '_${_isoDate(period.end)}.${format.extension}';

  /// Файлы содержат финансовые данные, поэтому прошлые выгрузки не копим.
  /// Удалять файл сразу после «Поделиться» нельзя: целевое приложение
  /// (например, мессенджер) может читать его уже после закрытия меню.
  static Future<void> _deleteStaleReports(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && p.basename(entity.path).startsWith(_filePrefix)) {
          await entity.delete();
        }
      }
    } catch (e, stack) {
      AppLogger.w('[ReportExport] Не удалось очистить старые отчёты', e, stack);
    }
  }

  static String _isoDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
