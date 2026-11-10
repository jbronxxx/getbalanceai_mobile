import 'package:flutter/material.dart';
import 'one_line_label.dart';

/// Кнопки модальных листов (операция, лимит, карточка операции, выгрузка
/// отчёта) в одном стиле: высота 54, скругление 16, подпись в одну строку —
/// при крупном шрифте она немного уменьшается, а не переносится.
abstract final class SheetButtons {
  static const double height = 54;
  static const double radius = 16;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );
  static const _padding = EdgeInsets.symmetric(horizontal: 8);

  static BorderSide _side(Color color) =>
      BorderSide(color: color.withValues(alpha: 0.5));

  /// Индикатор загрузки в кнопке на месте иконки.
  static Widget spinner(Color color) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color.withValues(alpha: 0.6),
        ),
      );
}

/// Основное действие листа: «Сохранить», «Добавить», «Скачать отчёт».
/// Кнопки действий — без иконок, только подпись.
class SheetPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Идёт действие: слева от подписи — индикатор загрузки.
  final bool busy;

  const SheetPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onPressed != null;
    final text = OneLineLabel(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: enabled
            ? colorScheme.onPrimary
            : colorScheme.onSurface.withValues(alpha: 0.38),
      ),
    );
    final style = ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      minimumSize: const Size.fromHeight(SheetButtons.height),
      padding: SheetButtons._padding,
      shape: SheetButtons._shape,
    );
    if (!busy) {
      return ElevatedButton(onPressed: onPressed, style: style, child: text);
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: SheetButtons.spinner(
          enabled ? colorScheme.onPrimary : colorScheme.onSurface),
      label: text,
    );
  }
}

/// Второе действие листа с контуром: «Удалить» (цвет ошибки). Без иконки.
class SheetOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Цвет подписи и контура; по умолчанию — основной цвет темы.
  final Color? color;

  const SheetOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: SheetButtons._side(color),
        minimumSize: const Size.fromHeight(SheetButtons.height),
        padding: SheetButtons._padding,
        shape: SheetButtons._shape,
      ),
      child: OneLineLabel(label),
    );
  }
}

/// Квадратная контурная кнопка-иконка рядом с основной («Поделиться»).
class SheetIconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const SheetIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      style: IconButton.styleFrom(
        foregroundColor: color,
        side: onPressed == null ? null : SheetButtons._side(color),
        fixedSize: const Size.square(SheetButtons.height),
        shape: SheetButtons._shape,
      ),
    );
  }
}
