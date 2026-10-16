import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/utils.dart';

/// Пометка над AI-советами: отчёт сохранён до последних изменений операций
/// или лимитов, суммы в тексте могут не совпадать с экраном «Бюджет».
///
/// С [onRefresh] — кнопка новой генерации; без него (суточная квота
/// исчерпана) — подсказка, что обновить можно завтра.
class InsightsOutdatedNote extends StatelessWidget {
  final VoidCallback? onRefresh;

  const InsightsOutdatedNote({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Container(
      key: const ValueKey('insights_outdated_note'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.warning.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.update_rounded, size: 20, color: colors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  onRefresh != null
                      ? l10n.insights_outdated_note
                      : '${l10n.insights_outdated_note} '
                          '${l10n.insights_outdated_tomorrow}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (onRefresh != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('insights_outdated_refresh'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.insights_outdated_refresh),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accentText,
                ),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
