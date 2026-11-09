import 'package:flutter/material.dart';
import '../../cubits/insights/insights_cubit.dart';
import '../../utils/utils.dart';

/// Карточка «анализировать нечего»: будущий месяц, месяц без операций или
/// с операциями меньше порога.
class InsightsUnavailableCard extends StatelessWidget {
  final InsightsUnavailableReason reason;

  const InsightsUnavailableCard({super.key, required this.reason});

  String _message(AppLocalizations l10n) {
    switch (reason) {
      case InsightsUnavailableReason.futureMonth:
        return l10n.insights_future_month;
      case InsightsUnavailableReason.noTransactions:
        return l10n.insights_no_transactions;
      case InsightsUnavailableReason.notEnoughTransactions:
        return l10n.insight_no_data;
    }
  }

  IconData get _icon {
    switch (reason) {
      case InsightsUnavailableReason.futureMonth:
        return Icons.event_available_rounded;
      case InsightsUnavailableReason.noTransactions:
        return Icons.receipt_long_rounded;
      case InsightsUnavailableReason.notEnoughTransactions:
        return Icons.playlist_add_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              _icon,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _message(context.l10n),
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
