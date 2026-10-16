import 'package:flutter/widgets.dart';

/// Скрывает клавиатуру от [child]: `viewInsets` всегда нулевые, нижний
/// `padding` — как без клавиатуры.
///
/// Нужен экранам под модальным листом: без него при выезде клавиатуры
/// `MediaQuery` меняется на каждом кадре анимации и перестраивает все
/// зависимые виджеты (`Scaffold` вкладок, навбар со стеклом).
class KeyboardInsetsIsolation extends StatelessWidget {
  final Widget child;

  const KeyboardInsetsIsolation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        viewInsets: EdgeInsets.zero,
        padding: data.padding.copyWith(bottom: data.viewPadding.bottom),
      ),
      child: child,
    );
  }
}
