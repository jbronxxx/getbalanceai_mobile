import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/models.dart';
import '../../services/entitlement_service.dart';
import '../../services/report_export_service.dart';
import '../../utils/utils.dart';

part 'report_export_state.dart';

/// Управляет формой выгрузки отчёта за период в CSV/PDF.
///
/// Файл формируется на устройстве из локальной базы; доступ к функции
/// проверяется через [EntitlementService] (будущее разделение тарифов).
class ReportExportCubit extends Cubit<ReportExportState> {
  final ReportExportService _exportService;
  final EntitlementService _entitlements;

  ReportExportCubit({
    required int month,
    required int year,
    ReportExportService? exportService,
    EntitlementService? entitlements,
  })  : _exportService = exportService ?? ReportExportService(),
        _entitlements = entitlements ?? EntitlementService.instance,
        super(ReportExportState(month: month, year: year));

  void selectPreset(ReportPeriodPreset preset) {
    if (state.isExporting) return;
    emit(state.copyWith(preset: preset, status: ReportExportStatus.idle));
  }

  /// Сохраняет свой диапазон дат и переключает форму на него.
  void setCustomPeriod(DateTime start, DateTime end) {
    if (state.isExporting) return;
    emit(state.copyWith(
      preset: ReportPeriodPreset.custom,
      customPeriod: ReportPeriod(start, end),
      status: ReportExportStatus.idle,
    ));
  }

  void selectFormat(ReportFormat format) {
    if (state.isExporting) return;
    emit(state.copyWith(format: format, status: ReportExportStatus.idle));
  }

  Future<void> export({
    required ReportDeliveryMode mode,
    required AppLocalizations l10n,
    required String languageCode,
    Rect? sharePositionOrigin,
  }) async {
    final period = state.period;
    if (period == null || state.isExporting) return;

    if (!_entitlements.isEnabled(AppFeature.reportExport)) {
      emit(state.copyWith(status: ReportExportStatus.locked));
      return;
    }

    emit(state.copyWith(status: ReportExportStatus.exporting, mode: mode));
    try {
      final outcome = await _exportService.export(
        period: period,
        format: state.format,
        mode: mode,
        l10n: l10n,
        languageCode: languageCode,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: switch (outcome) {
          ReportExportOutcome.completed => ReportExportStatus.success,
          ReportExportOutcome.empty => ReportExportStatus.empty,
          ReportExportOutcome.cancelled => ReportExportStatus.idle,
        },
      ));
    } catch (e, stack) {
      AppLogger.e('[ReportExport] Не удалось выгрузить отчёт', e, stack);
      if (isClosed) return;
      emit(state.copyWith(status: ReportExportStatus.failure));
    }
  }
}
