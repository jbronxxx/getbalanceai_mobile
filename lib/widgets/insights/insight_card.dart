import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../whole_words_text.dart';

/// Стеклянная карточка сообщения ИИ: совет на «Аналитике», «помощники
/// заняты» при сбое ИИ (и там же в шторке голосового ввода).
class InsightCard extends StatelessWidget {
  final String text;

  const InsightCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final glassBg = AppColors.of(context).cardGlassBackground;

    final glassBorder = AppColors.of(context).cardBorder;

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
            color: AppColors.of(context).cardShadow,
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
              color: AppColors.of(context).accentText,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: WholeWordsText(
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
