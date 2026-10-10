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

  /// Запрашивает список транзакций с бэкенда с поддержкой пагинации и фильтрации по дате.
  Future<PaginatedResponse<TransactionModel>> getTransactions({
    int limit = 50,
    String? cursor,
    DateTime? since,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.clamp(1, 100),
        if (cursor != null) 'cursor': cursor,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      };

      final response = await _dio.get(
        ApiConfig.transactions,
        queryParameters: queryParams,
        options: _authOptions(),
      );

      final dynamic data =
          response.data is Map ? response.data['data'] : response.data;
      if (data is Map) {
        return PaginatedResponse<TransactionModel>.fromJson(
          Map<String, dynamic>.from(data),
          (item) => TransactionModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        );
      } else if (data is List) {
        final items = data
            .whereType<Map>()
            .map((json) =>
                TransactionModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        return PaginatedResponse<TransactionModel>(
          items: items,
          hasMore: false,
          limit: limit,
        );
      }

      return PaginatedResponse<TransactionModel>(
        items: const [],
        hasMore: false,
        limit: limit,
      );
    } catch (e) {
      AppLogger.e('[TransactionApiService] Get transactions error', e);
      rethrow;
    }
  }

  /// Создать транзакцию на сервере.
  Future<TransactionModel> createTransaction(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        ApiConfig.transactions,
        data: data,
        options: _authOptions(),
      );

      return TransactionModel.fromJson(response.data['data']);
    } catch (e) {
      AppLogger.e('[TransactionApiService] Create transaction error', e);
      rethrow;
    }
  }

  /// Удалить транзакцию с сервера по ID.
  Future<void> deleteTransaction(String id, [String? token]) async {
    try {
      await _dio.delete(
        '${ApiConfig.transactions}$id',
        options: _authOptions(token),
      );
    } catch (e) {
      AppLogger.e('[TransactionApiService] Delete transaction error', e);
      rethrow;
    }
  }

  /// Удаляет транзакцию локально и на сервере (или добавляет в отложенные).
  Future<void> deleteTransactionEverywhere(Transaction transaction) async {
    final serverId = transaction.serverId;
    LocalDbService.instance.deleteTransaction(transaction.localId);

    if (serverId == null) return;

    if (!_isAuthenticated()) {
      await PendingDeletionsStore.instance.addTransaction(serverId);
      return;
    }

    try {
      await deleteTransaction(serverId);
    } catch (e) {
      AppLogger.w(
          '[TransactionApiService] Server delete failed, deferring: $e');
      await PendingDeletionsStore.instance.addTransaction(serverId);
    }
  }
}
