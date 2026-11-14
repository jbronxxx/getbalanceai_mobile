import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/app_logger.dart';

/// Тариф и лимиты вошедшего пользователя.
///
/// Источник правды — бэкенд (вебхуки RevenueCat): [status] приходит с
/// профилем (`GET /auth/me`), обновляется после покупки и восстановления
/// ([refresh]), а остатки — по ответам сервера ([recordUse] после
/// успешного разбора голоса, [markLimitReached] по `403
/// PLAN_LIMIT_REACHED`). Последний статус хранится на устройстве: без сети
/// Pro остаётся Pro (выгрузка отчётов). `null` — гость или статус ещё не
/// получен: доступ как у Free.
class SubscriptionApiService {
  static const storageKey = 'plan_status';

  final Dio _dio;
  final Options Function([String? explicitToken]) _authOptions;
  final DateTime Function() _now;

  final ValueNotifier<PlanStatus?> status = ValueNotifier(null);

  SubscriptionApiService({
    required Dio dio,
    required Options Function([String? explicitToken]) authOptions,
    DateTime Function()? now,
  })  : _dio = dio,
        _authOptions = authOptions,
        _now = now ?? DateTime.now;

  bool get isPro => status.value?.isPro ?? false;

  SubscriptionStatus get subscription =>
      status.value?.subscription ?? SubscriptionStatus.free;

  /// Лимит функции в текущем окне или `null`, если он неизвестен.
  FeatureLimit? limit(PlanFeature feature) =>
      status.value?.limits[feature]?.at(_now());

  /// Остатка функции нет до сброса окна — запрос заведомо получит `403`.
  bool isExhausted(PlanFeature feature) =>
      status.value?.limits[feature]?.isExhaustedAt(_now()) ?? false;

  /// Читает статус, сохранённый при прошлом запуске; [signedIn] = `false` —
  /// статус вышедшего пользователя стирается.
  Future<void> init({required bool signedIn}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!signedIn) {
        await prefs.remove(storageKey);
        return;
      }
      final raw = prefs.getString(storageKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        status.value = PlanStatus.fromProfile(data);
      }
    } catch (e) {
      AppLogger.w('[Subscription] Не удалось прочитать сохранённый тариф: $e');
    }
  }

  /// Новый статус из профиля; `null` — выход из аккаунта.
  Future<void> update(PlanStatus? value) async {
    status.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, jsonEncode(value.toJson()));
      }
    } catch (e) {
      AppLogger.w('[Subscription] Не удалось сохранить тариф: $e');
    }
  }

  /// Сервер выполнил вызов функции: остаток на один меньше.
  void recordUse(PlanFeature feature) {
    final value = status.value;
    final limit = value?.limits[feature];
    if (value == null || limit == null) return;
    update(value.withLimit(limit.consumed(_now())));
  }

  /// Ответ `403 PLAN_LIMIT_REACHED`: остатка нет до времени сброса.
  void markLimitReached(PlanLimitReached reached) {
    final value = status.value;
    final limit = value?.limits[reached.feature];
    final resetsAt = reached.resetsAt;
    if (value == null || limit == null || resetsAt == null) return;
    update(value.withLimit(limit.exhausted(resetsAt)));
  }

  /// Обновляет подписку из RevenueCat на сервере (после покупки и
  /// восстановления, не дожидаясь вебхука). Ошибки пробрасываются: `503` —
  /// RevenueCat на сервере не настроен или недоступен.
  Future<SubscriptionStatus> refresh() async {
    final response = await _dio.post(
      ApiConfig.subscriptionRefresh,
      options: _authOptions(),
    );
    final subscription = SubscriptionStatus.fromJson(
        response.data['data'] as Map<String, dynamic>);
    final value = status.value;
    await update(value == null
        ? PlanStatus(subscription: subscription)
        : value.copyWith(subscription: subscription));
    return subscription;
  }
}
