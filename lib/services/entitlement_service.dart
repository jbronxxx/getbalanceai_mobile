import 'api_service.dart';

/// Функции, доступные только в Pro. Лимиты, которые есть на обоих тарифах
/// (число ИИ-отчётов и голосовых записей), проверяет сервер, а приложение —
/// по остаткам в `SubscriptionApiService`.
enum AppFeature {
  /// Выгрузка отчётов за период в CSV и PDF.
  reportExport,

  /// ИИ-отчёт текущего месяца строится сам при открытии «Аналитики» и
  /// обновляется после изменения данных. На Free — только по кнопке
  /// «Получить отчёт», 1 в месяц.
  aiInsights,
}

/// Единая точка проверки доступа к функциям Pro.
class EntitlementService {
  final bool Function() _isPro;

  EntitlementService({bool Function()? isPro})
      : _isPro = isPro ?? (() => ApiService.instance.subscription.isPro);

  static EntitlementService instance = EntitlementService();

  /// Доступна ли функция текущему пользователю: последний известный тариф,
  /// в том числе без сети.
  bool isEnabled(AppFeature feature) => switch (feature) {
        AppFeature.reportExport || AppFeature.aiInsights => _isPro(),
      };
}
