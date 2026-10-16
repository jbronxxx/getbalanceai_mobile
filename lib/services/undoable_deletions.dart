import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/models.dart';
import '../utils/app_logger.dart';
import 'api_service.dart';

/// Отложенное удаление записей (операций, лимитов) с возможностью отмены.
///
/// Свайп или кнопка «Удалить» только скрывают запись: из локальной базы и
/// с сервера она удаляется через [delay], если пользователь не нажал
/// «Отменить». Если приложение закрыли раньше, запись остаётся — при
/// случайном удалении это безопасный исход.
///
/// Слушатели уведомляются, когда запись скрыта, возвращена или удалена.
class UndoableDeletions<T> extends ChangeNotifier {
  UndoableDeletions({
    required int Function(T item) idOf,
    required Future<void> Function(T item) commit,
    this.delay = const Duration(seconds: 5),
  })  : _idOf = idOf,
        _commit = commit;

  /// Операции: удаление локально и на сервере.
  static UndoableDeletions<Transaction> transactions() =>
      UndoableDeletions<Transaction>(
        idOf: (t) => t.localId,
        commit: (t) => ApiService.instance.deleteTransactionEverywhere(t),
      );

  /// Лимиты бюджета: удаление локально и на сервере.
  static UndoableDeletions<Budget> budgets() => UndoableDeletions<Budget>(
        idOf: (b) => b.localId,
        commit: (b) => ApiService.instance.deleteBudgetEverywhere(b),
      );

  final Duration delay;
  final int Function(T item) _idOf;
  final Future<void> Function(T item) _commit;
  final Map<int, ({T item, Timer timer})> _pending = {};
  bool _disposed = false;

  /// Скрыта ли запись в ожидании удаления.
  bool isPending(T item) => _pending.containsKey(_idOf(item));

  /// Скрывает запись и запускает отсчёт до удаления.
  void schedule(T item) {
    final id = _idOf(item);
    _pending.remove(id)?.timer.cancel();
    _pending[id] = (item: item, timer: Timer(delay, () => _run(id)));
    notifyListeners();
  }

  /// Возвращает запись; `false`, если она уже удалена.
  bool undo(T item) {
    final entry = _pending.remove(_idOf(item));
    if (entry == null) return false;
    entry.timer.cancel();
    notifyListeners();
    return true;
  }

  /// Удаляет все скрытые записи сразу, не дожидаясь [delay].
  void flush() {
    for (final id in _pending.keys.toList()) {
      _run(id);
    }
  }

  void _run(int id) {
    final entry = _pending.remove(id);
    if (entry == null) return;
    entry.timer.cancel();
    unawaited(
      _commit(entry.item).catchError((Object e, StackTrace s) {
        AppLogger.w('[UndoableDeletions] Delete failed', e, s);
      }),
    );
    // Локальное удаление выполняется синхронно в начале _commit
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    flush();
    super.dispose();
  }
}
