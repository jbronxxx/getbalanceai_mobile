import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/insights/insights_cubit.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/insights/expense_structure_section.dart';
import '../widgets/insights/insight_card.dart';
import '../widgets/insights/insights_generate_card.dart';
import '../widgets/insights/insights_outdated_note.dart';
import '../widgets/insights/insights_unavailable_card.dart';
import '../widgets/insights/report_export_action.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';
import 'paywall_screen.dart';

/// Экран AI-инсайтов и выгрузки отчёта за месяц в CSV/PDF (кнопка в шапке).
class InsightsScreen extends StatefulWidget {
  final InsightsCubit? cubit;
  final bool isActive;

  const InsightsScreen({
    super.key,
    this.cubit,
    this.isActive = true,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late InsightsCubit _cubit;
  bool _isLocalCubit = false;
  StreamSubscription<PlanLimitReached>? _limitSub;

  @override
  void initState() {
    super.initState();
    final period = SelectedPeriodService.instance.period;
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      _cubit = InsightsCubit(
        initialMonth: period.month,
        initialYear: period.year,
      );
      _isLocalCubit = true;
    }
    SelectedPeriodService.instance.periodNotifier.addListener(_onPeriodChanged);
    _limitSub = _cubit.limitReached.listen(_onLimitReached);

    _cubit.setActive(widget.isActive);
    if (widget.isActive) _activate();
  }

  /// Лимит ИИ-отчёта исчерпан: Free — пейволл, Pro — новый отчёт завтра.
  void _onLimitReached(PlanLimitReached reached) {
    if (!mounted) return;
    if (reached.plan == PlanCode.free) {
      PaywallScreen.showForLimit(context, reached);
    } else {
      AppAlerts.info(context, context.l10n.insights_outdated_tomorrow);
    }
  }

  /// Период меняется на любой вкладке, но запрос к AI уходит только при
  /// активной вкладке аналитики: в фоне период применится при её открытии.
  void _onPeriodChanged() {
    if (widget.isActive) _activate();
  }

  /// Применяет общий период к кубиту и перезапрашивает отчёт, если данные
  /// менялись, пока вкладка была скрыта; правила генерации — в [InsightsCubit].
  void _activate() {
    final period = SelectedPeriodService.instance.period;
    if (_cubit.selectedMonth != period.month ||
        _cubit.selectedYear != period.year) {
      _cubit.setPeriod(month: period.month, year: period.year);
    } else if (!_cubit.hasLoadedOnce || _cubit.hasDataChangedWhileHidden) {
      _cubit.resolvePeriod();
    }
  }

  @override
  void didUpdateWidget(InsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cubit != oldWidget.cubit && widget.cubit != null) {
      if (_isLocalCubit) {
        _cubit.close();
        _isLocalCubit = false;
      }
      _cubit = widget.cubit!;
      unawaited(_limitSub?.cancel());
      _limitSub = _cubit.limitReached.listen(_onLimitReached);
    }
    _cubit.setActive(widget.isActive);
    if (widget.isActive && !oldWidget.isActive) {
      _activate();
    }
  }

  @override
  void dispose() {
    SelectedPeriodService.instance.periodNotifier
        .removeListener(_onPeriodChanged);
    unawaited(_limitSub?.cancel());
    if (_isLocalCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: const _InsightsScreenView(),
    );
  }
}

class _InsightsScreenView extends StatelessWidget {
  const _InsightsScreenView();

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = AppColors.of(context).shellBackground;
    final topOffset = LiquidGlassAppBar.topContentPadding(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: Text(
          context.l10n.insights_header_title,
          style: AppTypography.screenTitle(context),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ValueListenableBuilder<MonthPeriod>(
              valueListenable: SelectedPeriodService.instance.periodNotifier,
              builder: (context, period, _) => ReportExportAction(
                selectedMonth: period.month,
                selectedYear: period.year,
              ),
            ),
          ),
        ],
      ),
      body: ScreenBodyCard(
        child: CustomPullToRefresh(
          releaseImmediately: true,
          topPadding: topOffset,
          onRefresh: () => context.read<InsightsCubit>().refresh(),
          // Один список, как на других вкладках: месяц, структура расходов,
          // затем AI-советы в состоянии кубита.
          child: ListView(
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              top: topOffset + 8,
              left: 16,
              right: 16,
              bottom: LiquidGlassNavBar.bottomContentPadding(context),
            ),
            children: [
              const PeriodSwitcher(),
              const ExpenseStructureSection(),
              BlocBuilder<InsightsCubit, InsightsState>(
                builder: (context, state) => _InsightsBody(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI-советы в зависимости от состояния [InsightsCubit].
class _InsightsBody extends StatelessWidget {
  final InsightsState state;

  const _InsightsBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    if (state is InsightsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: AiSparklesLoader()),
      );
    }
    if (state is InsightsUnavailable) {
      return InsightsUnavailableCard(reason: state.reason);
    }
    if (state is InsightsAwaitingRequest) {
      return InsightsGenerateCard(
        freeReportsPerMonth: state.freeReportsPerMonth,
        onGenerate: () => context.read<InsightsCubit>().requestReport(),
      );
    }
    if (state is InsightsNetworkError) {
      return const _NoNetworkMessage();
    }
    if (state is InsightsError) {
      return Column(
        children: [
          InsightCard(text: context.l10n.insights_assistants_busy_msg1),
          InsightCard(text: context.l10n.insights_assistants_busy_msg2),
        ],
      );
    }
    if (state is InsightsUnauthenticated) {
      return InsightCard(text: state.hint);
    }
    if (state is InsightsLoaded) {
      final cubit = context.read<InsightsCubit>();
      return Column(
        children: [
          if (state.isOutdated)
            InsightsOutdatedNote(
              onRefresh: state.refresh == InsightsRefresh.available
                  ? cubit.requestReport
                  : null,
              onUpgrade: state.refresh == InsightsRefresh.proOnly
                  ? () => PaywallScreen.show(context)
                  : null,
            ),
          for (final insight in state.insights) InsightCard(text: insight),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _NoNetworkMessage extends StatelessWidget {
  const _NoNetworkMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.wifi_off, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            context.l10n.no_network_title,
            style: AppTypography.screenTitle(context),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.no_network_desc,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
