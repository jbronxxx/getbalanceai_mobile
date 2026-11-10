import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/app_logger.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profile_state.dart';

/// Управляет состоянием авторизации, облачной синхронизацией и выходом из аккаунта.
class ProfileCubit extends Cubit<ProfileState> {
  final ApiService _api;
  final Connectivity _connectivity;

  /// Всё, что меняет число неотправленных и отклонённых изменений: правки
  /// пользователя, ответы сервера и очередь удалений.
  final Listenable _pendingSources = Listenable.merge([
    LocalDbService.transactionsChanged,
    LocalDbService.budgetsChanged,
    LocalDbService.syncStateChanged,
    PendingDeletionsStore.changed,
  ]);

  ProfileCubit({ApiService? api, Connectivity? connectivity})
      : _api = api ?? ApiService.instance,
        _connectivity = connectivity ?? Connectivity(),
        super(ProfileState(
          pendingSyncCount: _countPendingSync(),
          rejectedSyncCount: _countRejectedSync(),
        )) {
    _pendingSources.addListener(_refreshPendingSyncCount);
  }

  static int _countPendingSync() {
    final local = LocalDbService.isInitialized
        ? LocalDbService.instance.unsyncedCount
        : 0;
    return local + PendingDeletionsStore.instance.count;
  }

  static int _countRejectedSync() => LocalDbService.isInitialized
      ? LocalDbService.instance.rejectedTransactionsCount
      : 0;

  void _refreshPendingSyncCount() {
    if (isClosed) return;
    final count = _countPendingSync();
    final rejected = _countRejectedSync();
    if (count == state.pendingSyncCount &&
        rejected == state.rejectedSyncCount) {
      return;
    }
    emit(state.copyWith(
      pendingSyncCount: count,
      rejectedSyncCount: rejected,
      syncError: state.syncError,
    ));
  }

  @override
  Future<void> close() {
    _pendingSources.removeListener(_refreshPendingSyncCount);
    return super.close();
  }

  /// Запускает полную синхронизацию. Ошибка сохраняется в `state.syncError`.
  Future<void> startSync() async {
    if (state.syncStatus == SyncStatus.syncing) return;
    final attempt = state.syncAttempt + 1;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (isClosed) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      emit(state.copyWith(
        syncStatus: SyncStatus.noInternet,
        syncAttempt: attempt,
      ));
      return;
    }

    emit(state.copyWith(syncStatus: SyncStatus.syncing, syncAttempt: attempt));

    try {
      await _api.syncAll();
      if (isClosed) return;
      emit(state.copyWith(
        syncStatus: SyncStatus.success,
        rejectedSyncCount: _countRejectedSync(),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(syncStatus: SyncStatus.error, syncError: e));
    }
  }

  /// Есть ли что выгрузить перед выходом: неотправленные изменения или
  /// записи, ожидающие удаления после «Отменить».
  bool get hasChangesToUpload =>
      _countPendingSync() > 0 || UndoableDeletions.anyPending;

  /// Готовит выход: выполняет отложенные удаления и пробует выгрузить
  /// неотправленные изменения. Ошибки синхронизации не показываются —
  /// возвращается число изменений, которые останутся только на устройстве
  /// и будут удалены при выходе.
  Future<int> prepareLogout() async {
    await UndoableDeletions.flushAll();
    if (_countPendingSync() == 0) return 0;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        await _api.syncAll();
      }
    } catch (e) {
      AppLogger.w('[ProfileCubit] Sync before logout failed: $e');
    }
    return _countPendingSync();
  }

  /// Выходит из аккаунта и стирает его данные с устройства. Ошибки сервера
  /// не прерывают локальный выход: [ApiService.logout] очищает всё в любом
  /// случае.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (e) {
      AppLogger.w('[ProfileCubit] Server logout failed: $e');
    }
  }
}
