part of 'report_export_cubit.dart';

/// Быстрые варианты периода выгрузки.
enum ReportPeriodPreset { month, year, custom }

/// Этап выгрузки отчёта.
enum ReportExportStatus { idle, exporting, success, empty, locked, failure }

/// Состояние формы выгрузки отчёта.
@immutable
class ReportExportState {
  final ReportPeriodPreset preset;
  final int month;
  final int year;
  final ReportPeriod? customPeriod;
  final ReportFormat format;
  final ReportExportStatus status;

  /// Способ доставки текущей/последней выгрузки.
  final ReportDeliveryMode mode;

  const ReportExportState({
    required this.month,
    required this.year,
    this.preset = ReportPeriodPreset.month,
    this.customPeriod,
    this.format = ReportFormat.pdf,
    this.status = ReportExportStatus.idle,
    this.mode = ReportDeliveryMode.share,
  });

  /// Период для выгрузки; `null`, пока выбран свой диапазон, но даты не заданы.
  ReportPeriod? get period => switch (preset) {
        ReportPeriodPreset.month => ReportPeriod.month(month, year),
        ReportPeriodPreset.year => ReportPeriod.year(year),
        ReportPeriodPreset.custom => customPeriod,
      };

  bool get isExporting => status == ReportExportStatus.exporting;

  bool get canExport => period != null && !isExporting;

  ReportExportState copyWith({
    ReportPeriodPreset? preset,
    ReportPeriod? customPeriod,
    ReportFormat? format,
    ReportExportStatus? status,
    ReportDeliveryMode? mode,
  }) {
    return ReportExportState(
      month: month,
      year: year,
      preset: preset ?? this.preset,
      customPeriod: customPeriod ?? this.customPeriod,
      format: format ?? this.format,
      status: status ?? this.status,
      mode: mode ?? this.mode,
    );
  }
}
