import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Общее оформление модальных листов: фон, контур сверху и по бокам, тень.
class AppSheet {
  AppSheet._();

  static BoxDecoration decoration(BuildContext context) {
    final colors = AppColors.of(context);
    final side = BorderSide(color: colors.sheetBorder);
    return BoxDecoration(
      color: colors.sheetBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      border: Border(
        top: side.copyWith(width: 1.5),
        left: side,
        right: side,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.sheetShadow,
          blurRadius: 32,
          offset: const Offset(0, -8),
        ),
      ],
    );
  }
}

/// «Ручка» в верхней части модального листа.
class SheetHandle extends StatelessWidget {
  final double width;
  final double bottomMargin;

  const SheetHandle({super.key, this.width = 80, this.bottomMargin = 16});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? AppColors.of(context).sheetHandleDark
        : theme.colorScheme.outlineVariant;

    return Container(
      width: width,
      height: 4,
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
