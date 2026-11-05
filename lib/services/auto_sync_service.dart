import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import '../utils/app_logger.dart';
import 'api_service.dart';
import 'undoable_deletions.dart';

/// Фоновая синхронизация без участия пользователя.
///
/// Полный синк ([ApiService.syncAll]) запускается:
/// - при старте приложения;
/// - при возврате из фона — не чаще раза в [resumeInterval] после
///   успешного синка;
/// - при появлении сети после офлайна — через [networkDebounce], чтобы
///   переждать «дребезг» переключения Wi-Fi/мобильной сети.
///
/// При уходе в фон сразу выполняются отложенные удаления
/// ([UndoableDeletions.flush]): окно «Отменить» к этому моменту уже не видно,
/// а процесс в фоне система может убить.
///
/// Работает молча: ошибки только логируются, сообщения пользователю
/// показывает ручной синк (pull-to-refresh, Профиль). Без входа в аккаунт
/// и без сети ничего не делает.
class AutoSyncService {
  AutoSyncService({
    required Future<void> Function() sync,
    required bool Function() isAuthenticated,
    required Future<void> Function() flushDeletions,
    required Stream<List<ConnectivityResult>> connectivityChanges,
    required Future<List<ConnectivityResult>> Function() checkConnectivity,
    DateTime Function()? clock,
    this.resumeInterval = const Duration(minutes: 1),
    this.networkDebounce = const Duration(seconds: 2),
  })  : _sync = sync,
        _isAuthenticated = isAuthenticated,
        _flushDeletions = flushDeletions,
        _connectivityChanges = connectivityChanges,
        _checkConnectivity = checkConnectivity,
        _clock = clock ?? DateTime.now;

  /// Экземпляр приложения: синк через [ApiService], сеть — `connectivity_plus`.
  static final AutoSyncService instance = () {
    final connectivity = Connectivity();
    return AutoSyncService(
      sync: () => ApiService.instance.syncAll(),
      isAuthenticated: () => ApiService.instance.isAuthenticated,
      flushDeletions: () => Future.wait([
        UndoableDeletions.transactions.flush(),
        UndoableDeletions.budgets.flush(),
      ]),
      connectivityChanges: connectivity.onConnectivityChanged,
      checkConnectivity: connectivity.checkConnectivity,
    );
  }();

  final Duration resumeInterval;
  final Duration networkDebounce;

  final Future<void> Function() _sync;
  final bool Function() _isAuthenticated;
  final Future<void> Function() _flushDeletions;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final DateTime Function() _clock;

  AppLifecycleListener? _lifecycle;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _networkTimer;
  Future<void>? _running;
  DateTime? _lastSuccess;
  bool _offline = false;

  bool get isStarted => _lifecycle != null;

  /// Подписывается на жизненный цикл и сеть и запускает стартовый синк.
  /// Повторный вызов ничего не делает.
  void start() {
    if (isStarted) return;
    _lifecycle = AppLifecycleListener(onShow: _onShow, onHide: _onHide);
    _connectivitySub = _connectivityChanges.listen(_onConnectivityChanged);
    unawaited(_run('startup'));
  }

  void stop() {
    _lifecycle?.dispose();
    _lifecycle = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _networkTimer?.cancel();
    _networkTimer = null;
  }

  void _onShow() {
    final last = _lastSuccess;
    if (last != null && _clock().difference(last) < resumeInterval) return;
    unawaited(_run('resume'));
  }

  void _onHide() {
    unawaited(_flushDeletions().catchError((Object e, StackTrace s) {
      AppLogger.w('[AutoSync] Отложенные удаления не выполнены', e, s);
    }));
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final offline = _isOffline(result);
    final cameOnline = _offline && !offline;
    _offline = offline;
    _networkTimer?.cancel();
    if (!cameOnline) return;
    _networkTimer = Timer(networkDebounce, () => unawaited(_run('network')));
  }

  /// Один синк за раз: триггер во время идущего синка пропускается —
  /// тот и так отправит и загрузит актуальное.
  Future<void> _run(String reason) {
    if (_running != null || !_isAuthenticated()) return Future.value();
    final run = _syncIfOnline(reason);
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _syncIfOnline(String reason) async {
    try {
      if (_isOffline(await _checkConnectivity())) {
        // Синк запустится, когда появится сеть.
        _offline = true;
        return;
      }
      AppLogger.d('[AutoSync] Синхронизация: $reason');
      await _sync();
      _lastSuccess = _clock();
    } catch (e, s) {
      AppLogger.w('[AutoSync] Синхронизация ($reason) не удалась', e, s);
    }
  }

  static bool _isOffline(List<ConnectivityResult> result) =>
      result.isEmpty || result.contains(ConnectivityResult.none);
}
