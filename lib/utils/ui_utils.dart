import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Закрывает клавиатуру по тапу вне поля ввода — для `TextField.onTapOutside`.
///
/// На телефонах Flutter по умолчанию оставляет фокус в поле, и у цифровой
/// клавиатуры нет кнопки «Готово»: убрать её было нечем.
void unfocusOnTapOutside(PointerDownEvent event) =>
    FocusManager.instance.primaryFocus?.unfocus();

/// Строка, которая не переносится посередине: обычные пробелы заменены
/// неразрывными (суммы с разрядами, «1 декабря»).
String nonBreaking(String text) => text.replaceAll(' ', '\u00A0');

extension ShowSnackBar on BuildContext {
  void showMessage(String message, {bool isError = false}) {
    if (isError) {
      AppAlerts.error(this, message);
    } else {
      AppAlerts.success(this, message);
    }
  }
}
