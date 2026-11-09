part of 'profile_cubit.dart';

/// Статус облачной синхронизации на экране профиля.
enum SyncStatus { idle, syncing, success, error, noInternet }

/// Состояние экрана профиля: статус синхронизации, последняя ошибка
/// синхронизации, число изменений, ещё не отправленных на сервер, и сколько
/// из них сервер отклонил.
@immutable
class ProfileState {
  final SyncStatus syncStatus;
  final Object? syncError;

  /// Операции, лимиты и удаления, которые ещё не дошли до сервера.
  final int pendingSyncCount;

  /// Операции, которые сервер не принял при последней выгрузке (входят
  /// в [pendingSyncCount]).
  final int rejectedSyncCount;

  /// Номер нажатия «Синхронизировать». Повторная попытка без сети даёт тот
  /// же статус `noInternet` — по номеру экран понимает, что это новая
  /// попытка, и снова показывает сообщение.
  final int syncAttempt;

  const ProfileState({
    this.syncStatus = SyncStatus.idle,
    this.syncError,
    this.pendingSyncCount = 0,
    this.rejectedSyncCount = 0,
    this.syncAttempt = 0,
  });

  /// Возвращает копию состояния. `syncError` сбрасывается, если не передан явно.
  ProfileState copyWith({
    SyncStatus? syncStatus,
    Object? syncError,
    int? pendingSyncCount,
    int? rejectedSyncCount,
    int? syncAttempt,
  }) {
    return ProfileState(
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      rejectedSyncCount: rejectedSyncCount ?? this.rejectedSyncCount,
      syncAttempt: syncAttempt ?? this.syncAttempt,
    );
  }
}
