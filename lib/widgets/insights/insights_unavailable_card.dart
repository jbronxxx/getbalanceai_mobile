import 'package:flutter/material.dart';
import '../../cubits/insights/insights_cubit.dart';
import '../../utils/utils.dart';

/// Карточка «анализировать нечего»: будущий месяц или месяц без операций.
class InsightsUnavailableCard extends StatelessWidget {
  final InsightsUnavailableReason reason;

  const InsightsUnavailableCard({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFuture = reason == InsightsUnavailableReason.futureMonth;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFuture
                  ? Icons.event_available_rounded
                  : Icons.receipt_long_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isFuture
                  ? context.l10n.insights_future_month
                  : context.l10n.insights_no_transactions,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
