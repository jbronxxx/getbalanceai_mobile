import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/report_export/report_export_cubit.dart';
import '../../models/models.dart';
import '../../services/selected_period_service.dart';
import '../../utils/utils.dart';
import '../app_alerts.dart';
import '../app_choice_chip.dart';
import '../app_sheet.dart';
import '../sheet_buttons.dart';
import '../../theme/app_colors.dart';

/// Модальный лист выгрузки отчёта: период, формат и кнопка «Выгрузить».
class ReportExportSheet extends StatelessWidget {
  const ReportExportSheet({super.key});

  static Future<void> show(
    BuildContext context, {
    required int month,
    required int year,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => ReportExportCubit(month: month, year: year),
        child: const ReportExportSheet(),
      ),
    );
  }

  void _onStatusChanged(BuildContext context, ReportExportState state) {
    final l10n = context.l10n;
    switch (state.status) {
      case ReportExportStatus.success:
        if (state.mode == ReportDeliveryMode.save) {
          AppAlerts.success(context, l10n.report_saved);
        }
        Navigator.pop(context);
      case ReportExportStatus.empty:
        AppAlerts.info(context, l10n.report_empty_period);
      case ReportExportStatus.locked:
        AppAlerts.warning(context, l10n.report_feature_locked);
      case ReportExportStatus.failure:
        AppAlerts.error(context, l10n.report_export_error);
      case ReportExportStatus.idle:
      case ReportExportStatus.exporting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    return BlocConsumer<ReportExportCubit, ReportExportState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onStatusChanged,
      builder: (context, state) {
        // Оформление и кнопки — как у шторок операции и лимита. Системную
        // полоску снизу учитывает SafeArea.
        return Container(
          padding:
              const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
          decoration: AppSheet.decoration(context),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: SheetHandle()),
                  Text(
                    l10n.report_export_title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(l10n.report_period_label),
                  _PeriodChips(state: state),
                  const SizedBox(height: 20),
                  _SectionLabel(l10n.report_format_label),
                  _FormatChips(state: state),
                  const SizedBox(height: 24),
                  _ExportButtons(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Подпись над группой чипов («Период», «Формат»).
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Формат файла — чипы, как выбор периода над ними.
class _FormatChips extends StatelessWidget {
  final ReportExportState state;

  const _FormatChips({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportExportCubit>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final format in ReportFormat.values)
          AppChoiceChip(
            key: ValueKey('report_format_${format.name}'),
            label: format.extension.toUpperCase(),
            selected: state.format == format,
            onTap: state.isExporting ? null : () => cubit.selectFormat(format),
          ),
      ],
    );
  }
}

/// Выбор периода: месяц/год из экрана или свой диапазон дат.
class _PeriodChips extends StatelessWidget {
  final ReportExportState state;

  const _PeriodChips({required this.state});

  Future<void> _pickRange(BuildContext context) async {
    final cubit = context.read<ReportExportCubit>();
    final current = state.period;
    // Границы — как у шапки периода: месяц и год из неё всегда попадают
    // в календарь (иначе на +2…+5 годах initialDateRange вне lastDate).
    final periods = SelectedPeriodService.instance;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: periods.firstDate,
      lastDate: periods.lastDate,
      initialDateRange: current == null
          ? null
          : DateTimeRange(start: current.start, end: current.end),
    );
    if (picked != null) {
      cubit.setCustomPeriod(picked.start, picked.end);
    }
  }

  String _customLabel(BuildContext context) {
    final period = state.customPeriod;
    final base = context.l10n.report_period_custom;
    if (period == null) return base;
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(period.start)} — '
        '${localizations.formatShortDate(period.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ReportExportCubit>();
    final enabled = !state.isExporting;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppChoiceChip(
          label: '${LanguageManager.getMonthName(state.month)} ${state.year}',
          selected: state.preset == ReportPeriodPreset.month,
          onTap: enabled
              ? () => cubit.selectPreset(ReportPeriodPreset.month)
              : null,
        ),
        AppChoiceChip(
          label: '${l10n.report_period_year} ${state.year}',
          selected: state.preset == ReportPeriodPreset.year,
          onTap: enabled
              ? () => cubit.selectPreset(ReportPeriodPreset.year)
              : null,
        ),
        AppChoiceChip(
          icon: Icons.calendar_today_rounded,
          label: _customLabel(context),
          selected: state.preset == ReportPeriodPreset.custom,
          onTap: enabled ? () => _pickRange(context) : null,
        ),
      ],
    );
  }
}

/// Широкая акцентная кнопка «Скачать отчёт» (сохранение в память устройства
/// через системный диалог) и компактная иконка «Поделиться» (системное меню:
/// мессенджеры, почта, «Файлы»).
class _ExportButtons extends StatelessWidget {
  final ReportExportState state;

  const _ExportButtons({required this.state});

  void _export(BuildContext buttonContext, ReportDeliveryMode mode) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    // На iPad системному меню нужна точка привязки.
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    buttonContext.read<ReportExportCubit>().export(
          mode: mode,
          l10n: buttonContext.l10n,
          languageCode: Localizations.localeOf(buttonContext).languageCode,
          sharePositionOrigin: origin,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    bool busy(ReportDeliveryMode mode) =>
        state.isExporting && state.mode == mode;

    return Row(
      children: [
        Expanded(
          child: Builder(
            builder: (buttonContext) => SheetPrimaryButton(
              key: const ValueKey('report_download_button'),
              label: l10n.report_save_action,
              onPressed: state.canExport
                  ? () => _export(buttonContext, ReportDeliveryMode.save)
                  : null,
              busy: busy(ReportDeliveryMode.save),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Builder(
          builder: (buttonContext) => SheetIconButton(
            key: const ValueKey('report_share_button'),
            tooltip: l10n.report_share_action,
            onPressed: state.canExport
                ? () => _export(buttonContext, ReportDeliveryMode.share)
                : null,
            icon: busy(ReportDeliveryMode.share)
                ? SheetButtons.spinner(Theme.of(context).colorScheme.primary)
                : const Icon(Icons.ios_share_rounded),
          ),
        ),
      ],
    );
  }
}
