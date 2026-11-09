import 'package:flutter/material.dart';
import 'swipe_hint_wrapper.dart';

/// Удаление свайпом влево — единое для строк операций и карточек лимитов.
///
/// Скругление задаётся здесь, одним [borderRadius] на сдвигаемый [child] и
/// красную подложку вместе. Сам [child] должен быть прямоугольным, с
/// непрозрачным фоном и без своих скруглённых углов: `Dismissible` открывает
/// подложку прямоугольником справа от [child], и скруглённые углы [child]
/// оставляли бы между собой и подложкой щель с фоном экрана.
class SwipeToDelete extends StatelessWidget {
  /// Ключ записи для `Dismissible`.
  final Key dismissKey;
  final VoidCallback onDelete;
  final Widget child;
  final BorderRadius borderRadius;

  /// Показать анимацию-подсказку «свайпни, чтобы удалить» (первая запись).
  final bool showHint;
  final VoidCallback? onHintShown;

  const SwipeToDelete({
    super.key,
    required this.dismissKey,
    required this.onDelete,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.showHint = false,
    this.onHintShown,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = Container(
      key: const ValueKey('swipe_delete_background'),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: colorScheme.error,
      child: Icon(Icons.delete_rounded, color: colorScheme.onError),
    );

    final dismissible = Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: kSwipeDeleteThreshold,
      },
      onDismissed: (_) => onDelete(),
      background: background,
      child: child,
    );

    final content = SwipeHintWrapper(
      showHint: showHint,
      background: background,
      onHintShown: onHintShown,
      child: dismissible,
    );

    if (borderRadius == BorderRadius.zero) return content;
    return ClipRRect(borderRadius: borderRadius, child: content);
  }
}
