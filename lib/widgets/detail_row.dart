import 'package:flutter/material.dart';
import 'whole_words_text.dart';

/// Строка карточки «подпись — значение» (карточка операции, регулярного
/// платежа).
///
/// Значение занимает сколько нужно, но не больше 60% строки, подпись —
/// остальное: при крупном шрифте ни длинная категория, ни подпись
/// («В основной валюте») не рвутся посреди слова.
class DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const DetailRow({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: WholeWordsText(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
