import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';

/// Сервис взаимодействия с API бюджетов.
class BudgetApiService {
  final Dio _dio;
  final Options Function([String? token]) _authOptions;
  final bool Function() _isAuthenticated;

  BudgetApiService({
    required Dio dio,
    required Options Function([String? token]) authOptions,
    required bool Function() isAuthenticated,
  })  : _dio = dio,
        _authOptions = authOptions,
        _isAuthenticated = isAuthenticated;

  /// Удалить бюджет с сервера по ID.
  Future<void> deleteBudget(String id, [String? token]) async {
    try {
      await _dio.delete(
        '${ApiConfig.budgets}$id',
        options: _authOptions(token),
      );
    } catch (e) {
      AppLogger.e('[BudgetApiService] Delete budget error', e);
      rethrow;
    }
  }

  /// Удаляет бюджет локально и на сервере (или добавляет в отложенные).
  Future<void> deleteBudgetEverywhere(Budget budget) async {
    // Актуальный serverId — из базы, см. deleteTransactionEverywhere.
    final serverId =
        LocalDbService.instance.getBudget(budget.localId)?.serverId ??
            budget.serverId;
    LocalDbService.instance.deleteBudget(budget.localId);

    if (serverId == null) return;

    if (!_isAuthenticated()) {
      await PendingDeletionsStore.instance.addBudget(serverId);
      return;
    }

    try {
      await deleteBudget(serverId);
    } catch (e) {
      AppLogger.w(
          '[BudgetApiService] Server budget delete failed, deferring: $e');
      await PendingDeletionsStore.instance.addBudget(serverId);
    }
  }
}
