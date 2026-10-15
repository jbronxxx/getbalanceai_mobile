import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/insights/insights_cubit.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/insights/expense_structure_section.dart';
import '../widgets/insights/insights_generate_card.dart';
import '../widgets/insights/insights_unavailable_card.dart';
import '../widgets/period/period.dart';
import '../widgets/widgets.dart';

/// Экран AI-инсайтов.
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

    if (widget.isActive) _activate();
  }

  /// Период меняется на любой вкладке, но запрос к AI уходит только при
  /// активной вкладке аналитики: в фоне период применится при её открытии.
  void _onPeriodChanged() {
    if (widget.isActive) _activate();
  }

  /// Применяет общий период к кубиту; правила генерации — в [InsightsCubit].
  void _activate() {
    final period = SelectedPeriodService.instance.period;
    if (_cubit.selectedMonth != period.month ||
        _cubit.selectedYear != period.year) {
      _cubit.setPeriod(month: period.month, year: period.year);
    } else if (!_cubit.hasLoadedOnce) {
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
    }
    if (widget.isActive && !oldWidget.isActive) {
      _activate();
    }
  }

  @override
  void dispose() {
    SelectedPeriodService.instance.periodNotifier
        .removeListener(_onPeriodChanged);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg =
        isDark ? const Color(0xFF09090B) : const Color(0xFFEFF2F6);
    final topOffset = LiquidGlassAppBar.topContentPadding(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: LiquidGlassAppBar(
        title: Text(
          context.l10n.insights_header_title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: ScreenBodyCard(
        child: CustomPullToRefresh(
          releaseImmediately: true,
          topPadding: topOffset,
          onRefresh: () =>
              context.read<InsightsCubit>().loadInsights(force: true),
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
        onGenerate: () => context.read<InsightsCubit>().loadInsights(),
      );
    }
    if (state is InsightsNetworkError) {
      return const _NoNetworkMessage();
    }
    if (state is InsightsError) {
      return Column(
        children: [
          _InsightCard(text: context.l10n.insights_assistants_busy_msg1),
          _InsightCard(text: context.l10n.insights_assistants_busy_msg2),
        ],
      );
    }
    if (state is InsightsUnauthenticated) {
      return _InsightCard(text: state.hint);
    }
    if (state is InsightsLoaded) {
      return Column(
        children: [
          for (final insight in state.insights) _InsightCard(text: insight),
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
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
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

class _InsightCard extends StatelessWidget {
  final String text;

  const _InsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final glassBg = isDark
        ? const Color(0xFF141416).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.85);

    final glassBorder =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: glassBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
