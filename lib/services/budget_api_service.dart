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

  /// Получить бюджеты с сервера.
  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    try {
      final response = await _dio.get(
        ApiConfig.budgets,
        queryParameters: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        },
        options: _authOptions(),
      );

      final List<dynamic> list = response.data['data'];
      return list.map((json) => BudgetModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.e('[BudgetApiService] Get budgets error', e);
      rethrow;
    }
  }

  /// Создать бюджет на сервере.
  Future<BudgetModel> createBudget(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        ApiConfig.budgets,
        data: data,
        options: _authOptions(),
      );

      return BudgetModel.fromJson(response.data['data']);
    } catch (e) {
      AppLogger.e('[BudgetApiService] Create budget error', e);
      rethrow;
    }
  }

  /// Обновить или создать бюджет.
  Future<BudgetModel> updateBudget(Map<String, dynamic> data) async {
    return createBudget(data);
  }

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

  /// Удалить бюджет по категории и периоду.
  Future<void> deleteBudgetByPeriod(
    String category,
    int month,
    int year, [
    String? token,
  ]) async {
    try {
      await _dio.delete(
        '${ApiConfig.budgets}category/$category/$month/$year',
        options: _authOptions(token),
      );
    } catch (e) {
      AppLogger.e('[BudgetApiService] Delete budget by period error', e);
      rethrow;
    }
  }

  /// Удаляет бюджет локально и на сервере (или добавляет в отложенные).
  Future<void> deleteBudgetEverywhere(Budget budget) async {
    final serverId = budget.serverId;
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
