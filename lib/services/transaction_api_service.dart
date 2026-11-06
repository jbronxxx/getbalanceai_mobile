import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';

/// Сервис взаимодействия с API транзакций.
class TransactionApiService {
  final Dio _dio;
  final Options Function([String? token]) _authOptions;
  final bool Function() _isAuthenticated;

  TransactionApiService({
    required Dio dio,
    required Options Function([String? token]) authOptions,
    required bool Function() isAuthenticated,
  })  : _dio = dio,
        _authOptions = authOptions,
        _isAuthenticated = isAuthenticated;

  /// Удалить транзакцию с сервера по ID.
  Future<void> deleteTransaction(String id) async {
    try {
      await _dio.delete(
        '${ApiConfig.transactions}$id',
        options: _authOptions(),
      );
    } catch (e) {
      AppLogger.e('[TransactionApiService] Delete transaction error', e);
      rethrow;
    }
  }

  /// Удаляет транзакцию локально и на сервере (или добавляет в отложенные).
  Future<void> deleteTransactionEverywhere(Transaction transaction) async {
    // Объект из списка мог устареть: serverId присваивается фоновой
    // выгрузкой уже после того, как экран прочитал строку. Без актуального
    // serverId удаление осталось бы локальным, и запись вернулась бы с сервера.
    final serverId =
        LocalDbService.instance.getTransaction(transaction.localId)?.serverId ??
            transaction.serverId;
    LocalDbService.instance.deleteTransaction(transaction.localId);

    if (serverId == null) return;

    // «Надгробие» — до запроса: если процесс убьют посреди удаления (оно
    // выполняется и при сворачивании приложения), запись не вернётся с
    // сервера при следующей загрузке. Повтор DELETE безопасен: 404 — успех.
    await PendingDeletionsStore.instance.addTransaction(serverId);
    if (!_isAuthenticated()) return;

    try {
      await deleteTransaction(serverId);
      await PendingDeletionsStore.instance.removeTransactions([serverId]);
    } catch (e) {
      AppLogger.w(
          '[TransactionApiService] Server delete failed, deferring: $e');
    }
  }
}
