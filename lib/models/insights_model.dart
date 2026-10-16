/// Состояние AI-отчёта за период (поле `state` ответа бэкенда).
enum InsightsReportState {
  /// Отчёт есть (сгенерирован или сохранённый).
  ready,

  /// Отчёта нет, генерация не запрашивалась (`generate=false`).
  notGenerated,

  /// Будущий месяц или нет операций за период.
  noData,

  /// Суточная квота исчерпана; `insights` — сообщение о лимите или
  /// устаревший сохранённый отчёт ([InsightsModel.isOutdated]).
  quotaExceeded,

  /// AI временно недоступен; ответ нельзя показывать как отчёт и кэшировать.
  busy;

  /// Значение из JSON; неизвестное или отсутствующее (старый бэкенд) — [ready].
  static InsightsReportState fromJson(dynamic value) {
    switch (value) {
      case 'not_generated':
        return InsightsReportState.notGenerated;
      case 'no_data':
        return InsightsReportState.noData;
      case 'quota_exceeded':
        return InsightsReportState.quotaExceeded;
      case 'busy':
        return InsightsReportState.busy;
      default:
        return InsightsReportState.ready;
    }
  }
}

/// DTO модели ответа AI-аналитики (`GET /api/v1/insights/`).
class InsightsModel {
  final List<String> insights;
  final DateTime? generatedAt;
  final InsightsReportState state;

  /// Сохранённый отчёт, а операции или лимиты месяца изменились после его
  /// генерации: суммы в тексте могут не совпадать с экраном.
  final bool isOutdated;

  const InsightsModel({
    required this.insights,
    this.generatedAt,
    this.state = InsightsReportState.ready,
    this.isOutdated = false,
  });

  /// Безопасный парсинг даты из ответа бэкенда.
  ///
  /// Поддерживает ISO-8601 строки (включая UTC с суффиксом Z),
  /// а также unix-timestamp в секундах или миллисекундах.
  static DateTime? parseGeneratedAt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is num) {
      final intVal = value.toInt();
      return intVal > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(intVal)
          : DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
    }
    return null;
  }

  factory InsightsModel.fromJson(Map<String, dynamic> json) {
    final payload =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;

    return InsightsModel(
      insights: (payload['insights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      generatedAt: parseGeneratedAt(payload['generated_at']),
      state: InsightsReportState.fromJson(payload['state']),
      isOutdated: payload['is_outdated'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'insights': insights,
        'generated_at': generatedAt?.toIso8601String(),
      };
}
