import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/insights/insights_cubit.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Экран AI-инсайтов.
class InsightsScreen extends StatelessWidget {
  final InsightsCubit? cubit;

  const InsightsScreen({
    super.key,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _InsightsScreenView(),
      );
    }
    return BlocProvider(
      create: (_) => InsightsCubit()..loadInsights(),
      child: const _InsightsScreenView(),
    );
  }
}

class _InsightsScreenView extends StatelessWidget {
  static const double _topContentPadding = 94.0;

  const _InsightsScreenView();

  Widget _buildLoadingPlaceholder(double topPadding) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: topPadding,
            left: 16,
            right: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - topPadding)
                  .clamp(0.0, double.infinity),
            ),
            child: const Center(
              child: AiSparklesLoader(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBusyCardsList(BuildContext context, double topPadding) {
    final busyInsights = [
      context.l10n.insights_assistants_busy_msg1,
      context.l10n.insights_assistants_busy_msg2,
    ];

    return ListView.builder(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(
        top: topPadding,
        left: 16,
        right: 16,
        bottom: LiquidGlassNavBar.bottomContentPadding(context),
      ),
      itemCount: busyInsights.length,
      itemBuilder: (context, index) {
        return _buildInsightCard(context, busyInsights[index]);
      },
    );
  }

  Widget _buildNoNetworkPlaceholder(BuildContext context, double topPadding) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: topPadding,
            left: 16,
            right: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - topPadding)
                  .clamp(0.0, double.infinity),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          ),
        );
      },
    );
  }

  Widget _buildInsightCard(BuildContext context, String text) {
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

  Widget _buildFloatingTopBanner(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488)
                  .withValues(alpha: isDark ? 0.25 : 0.14),
              blurRadius: 14,
              spreadRadius: -3,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D9488)
                        .withValues(alpha: isDark ? 0.82 : 0.85),
                    const Color(0xFF0F766E)
                        .withValues(alpha: isDark ? 0.84 : 0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.l10n.insights_header_subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg =
        isDark ? const Color(0xFF09090B) : const Color(0xFFEFF2F6);
    final topOffset = LiquidGlassAppBar.topContentPadding(context);
    final effectiveTopPadding = topOffset + _topContentPadding;

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
          onRefresh: () => context.read<InsightsCubit>().loadInsights(),
          child: Stack(
            children: [
              Positioned.fill(
                child: BlocBuilder<InsightsCubit, InsightsState>(
                  builder: (context, state) {
                    if (state is InsightsLoading || state is InsightsInitial) {
                      return _buildLoadingPlaceholder(effectiveTopPadding);
                    } else if (state is InsightsNetworkError) {
                      return _buildNoNetworkPlaceholder(
                          context, effectiveTopPadding);
                    } else if (state is InsightsError) {
                      return _buildBusyCardsList(context, effectiveTopPadding);
                    } else if (state is InsightsUnauthenticated) {
                      return ListView.builder(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(
                          top: effectiveTopPadding,
                          left: 16,
                          right: 16,
                          bottom:
                              LiquidGlassNavBar.bottomContentPadding(context),
                        ),
                        itemCount: 1,
                        itemBuilder: (context, index) {
                          return _buildInsightCard(context, state.hint);
                        },
                      );
                    } else if (state is InsightsLoaded) {
                      return ListView.builder(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(
                          top: effectiveTopPadding,
                          left: 16,
                          right: 16,
                          bottom:
                              LiquidGlassNavBar.bottomContentPadding(context),
                        ),
                        itemCount: state.insights.length,
                        itemBuilder: (context, index) {
                          return _buildInsightCard(
                            context,
                            state.insights[index],
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              Positioned(
                top: topOffset + 8,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: _buildFloatingTopBanner(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
