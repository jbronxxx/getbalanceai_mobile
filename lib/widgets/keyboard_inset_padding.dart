import 'package:flutter/widgets.dart';

/// Отступ модального листа под клавиатуру.
///
/// Подписан только на `viewInsets`: во время анимации клавиатуры
/// перестраивается сам отступ, а содержимое листа ([child]) — нет.
class KeyboardInsetPadding extends StatelessWidget {
  final Widget child;

  const KeyboardInsetPadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
  }
}
