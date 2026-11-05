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

  /// Всё, что меняет число неотправленных изменений: правки пользователя,
  /// подтверждения сервера и очередь удалений.
  final Listenable _pendingSources = Listenable.merge([
    LocalDbService.transactionsChanged,
    LocalDbService.budgetsChanged,
    LocalDbService.syncStateChanged,
    PendingDeletionsStore.changed,
  ]);

  ProfileCubit({ApiService? api, Connectivity? connectivity})
      : _api = api ?? ApiService.instance,
        _connectivity = connectivity ?? Connectivity(),
        super(ProfileState(pendingSyncCount: _countPendingSync())) {
    _pendingSources.addListener(_refreshPendingSyncCount);
  }

  static int _countPendingSync() {
    final local = LocalDbService.isInitialized
        ? LocalDbService.instance.unsyncedCount
        : 0;
    return local + PendingDeletionsStore.instance.count;
  }

  void _refreshPendingSyncCount() {
    if (isClosed) return;
    final count = _countPendingSync();
    if (count == state.pendingSyncCount) return;
    emit(state.copyWith(pendingSyncCount: count, syncError: state.syncError));
  }

  @override
  Future<void> close() {
    _pendingSources.removeListener(_refreshPendingSyncCount);
    return super.close();
  }

  /// Запускает полную синхронизацию. Ошибка сохраняется в `state.syncError`.
  Future<void> startSync() async {
    if (state.syncStatus == SyncStatus.syncing) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (isClosed) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      emit(state.copyWith(syncStatus: SyncStatus.noInternet));
      return;
    }

    emit(state.copyWith(syncStatus: SyncStatus.syncing));

    try {
      await _api.syncAll();
      if (isClosed) return;
      emit(state.copyWith(syncStatus: SyncStatus.success));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(syncStatus: SyncStatus.error, syncError: e));
    }
  }

  /// Отзывает сессию на сервере. Ошибки сервера не прерывают локальный выход:
  /// токены очищаются в [ApiService.logout] в любом случае.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (e) {
      AppLogger.w('[ProfileCubit] Server logout failed: $e');
    }
  }
}
