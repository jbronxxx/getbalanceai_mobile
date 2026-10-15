import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/report_export/report_export_cubit.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../app_alerts.dart';

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
      backgroundColor: Colors.transparent,
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
        return Container(
          padding: EdgeInsets.only(
            top: 10,
            left: 24,
            right: 24,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  l10n.report_export_title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Text(l10n.report_period_label, style: textTheme.labelLarge),
                const SizedBox(height: 8),
                _PeriodChips(state: state),
                const SizedBox(height: 20),
                Text(l10n.report_format_label, style: textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ReportFormat>(
                    showSelectedIcon: false,
                    segments: [
                      for (final f in ReportFormat.values)
                        ButtonSegment(
                          value: f,
                          label: Text(f.extension.toUpperCase()),
                        ),
                    ],
                    selected: {state.format},
                    onSelectionChanged: state.isExporting
                        ? null
                        : (value) => context
                            .read<ReportExportCubit>()
                            .selectFormat(value.first),
                  ),
                ),
                const SizedBox(height: 24),
                _ExportButtons(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Выбор периода: месяц/год из экрана или свой диапазон дат.
class _PeriodChips extends StatelessWidget {
  final ReportExportState state;

  const _PeriodChips({required this.state});

  Future<void> _pickRange(BuildContext context) async {
    final cubit = context.read<ReportExportCubit>();
    final now = DateTime.now();
    final current = state.period;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
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
        ChoiceChip(
          label: Text(
            '${LanguageManager.getMonthName(state.month)} ${state.year}',
          ),
          selected: state.preset == ReportPeriodPreset.month,
          onSelected: enabled
              ? (_) => cubit.selectPreset(ReportPeriodPreset.month)
              : null,
        ),
        ChoiceChip(
          label: Text('${l10n.report_period_year} ${state.year}'),
          selected: state.preset == ReportPeriodPreset.year,
          onSelected: enabled
              ? (_) => cubit.selectPreset(ReportPeriodPreset.year)
              : null,
        ),
        ChoiceChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(_customLabel(context)),
          selected: state.preset == ReportPeriodPreset.custom,
          onSelected: enabled ? (_) => _pickRange(context) : null,
        ),
      ],
    );
  }
}

/// Кнопки «Сохранить» (в память устройства) и «Поделиться».
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

  Widget _spinner() => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    bool busy(ReportDeliveryMode mode) =>
        state.isExporting && state.mode == mode;

    return Row(
      children: [
        Expanded(
          child: Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: state.canExport
                  ? () => _export(buttonContext, ReportDeliveryMode.save)
                  : null,
              icon: busy(ReportDeliveryMode.save)
                  ? _spinner()
                  : const Icon(Icons.save_alt_rounded),
              label: Text(l10n.report_save_action),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: state.canExport
                  ? () => _export(buttonContext, ReportDeliveryMode.share)
                  : null,
              icon: busy(ReportDeliveryMode.share)
                  ? _spinner()
                  : const Icon(Icons.ios_share_rounded),
              label: Text(l10n.report_share_action),
            ),
          ),
        ),
      ],
    );
  }
}
