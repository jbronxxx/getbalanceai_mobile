import 'package:flutter/widgets.dart';

/// Откладывает перечитывание данных у скрытой вкладки до её показа.
///
/// Вкладки `MainShell` живут в `IndexedStack`, скрытые обёрнуты в
/// `TickerMode(enabled: false)`. Без этого сохранение операции синхронно,
/// ещё до закрытия формы, перечитывало месяц на каждой вкладке, включая
/// невидимые. Видимая вкладка перечитывает данные сразу, скрытая — один раз
/// при показе (до первого кадра), сколько бы изменений ни накопилось.
///
/// Слушатели изменений данных вызывают [requestReload] вместо прямой
/// загрузки; сама загрузка — в [reloadData].
mixin ReloadWhenVisible<T extends StatefulWidget> on State<T> {
  bool _visible = true;
  bool _reloadPending = false;

  /// Перечитывает данные экрана. Вызывается только для видимого экрана.
  void reloadData();

  /// Данные изменились: перечитать сейчас или при показе вкладки.
  void requestReload() {
    if (!mounted) return;
    if (_visible) {
      _reloadPending = false;
      reloadData();
    } else {
      _reloadPending = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Зависимость от TickerMode: при показе вкладки Flutter вызовет этот
    // метод перед её сборкой.
    _visible = TickerMode.valuesOf(context).enabled;
    if (_visible && _reloadPending) {
      _reloadPending = false;
      reloadData();
    }
  }
}
