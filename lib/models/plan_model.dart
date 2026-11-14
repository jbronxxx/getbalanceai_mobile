/// Тариф пользователя (`subscription.plan` в `GET /auth/me`).
enum PlanCode {
  free,
  pro;

  /// Неизвестное значение — [free]: доступ шире бесплатного даёт только
  /// подтверждённый сервером Pro.
  static PlanCode fromJson(dynamic value) =>
      value == 'pro' ? PlanCode.pro : PlanCode.free;
}

/// Функция с лимитом по тарифу.
enum PlanFeature {
  /// Генерация ИИ-отчёта за месяц (`GET /insights` с `generate=true`).
  aiReport('ai_report'),

  /// Разбор голосового ввода (`POST /voice/parse`).
  voice('voice');

  final String code;

  const PlanFeature(this.code);

  static PlanFeature? fromJson(dynamic value) {
    for (final feature in values) {
      if (feature.code == value) return feature;
    }
    return null;
  }
}

/// Окно лимита: календарные сутки или месяц по часам пользователя.
enum LimitPeriod {
  day,
  month;

  static LimitPeriod fromJson(dynamic value) =>
      value == 'month' ? LimitPeriod.month : LimitPeriod.day;
}

/// Лимиты Pro для пейволла: в профиле сервер отдаёт лимиты только текущего
/// тарифа. Значения — как `PRO_AI_REPORTS_PER_DAY` и `PRO_VOICE_PER_DAY`
/// на бэкенде; бесплатные берутся из профиля, а до него — из [freeDefaults].
abstract final class PlanCatalog {
  static const proAiReportsPerDay = 5;
  static const proVoicePerDay = 30;

  /// Как `FREE_AI_REPORTS_PER_MONTH` и `FREE_VOICE_PER_DAY` на бэкенде.
  static const freeAiReportsPerMonth = 1;
  static const freeVoicePerDay = 5;
}

DateTime? _parseDate(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// Тариф и срок подписки Pro.
class SubscriptionStatus {
  final PlanCode plan;

  /// Pro: дата продления ([willRenew]) или окончания доступа; Free — дата
  /// окончания прошлой подписки или `null`.
  final DateTime? expiresAt;

  /// Подписка продлится сама: отмены в магазине нет.
  final bool willRenew;

  /// Идёт бесплатный пробный период.
  final bool isTrial;

  const SubscriptionStatus({
    required this.plan,
    this.expiresAt,
    this.willRenew = false,
    this.isTrial = false,
  });

  static const free = SubscriptionStatus(plan: PlanCode.free);

  bool get isPro => plan == PlanCode.pro;

  /// Pro, который продлится и спишет деньги: удаление аккаунта его не
  /// отменяет.
  bool get renewsPaid => isPro && willRenew;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        plan: PlanCode.fromJson(json['plan']),
        expiresAt: _parseDate(json['expires_at']),
        willRenew: json['will_renew'] == true,
        isTrial: json['is_trial'] == true,
      );

  Map<String, dynamic> toJson() => {
        'plan': plan.name,
        'expires_at': expiresAt?.toIso8601String(),
        'will_renew': willRenew,
        'is_trial': isTrial,
      };
}

/// Лимит функции на тарифе и его расход в текущем окне.
class FeatureLimit {
  final PlanFeature feature;
  final LimitPeriod period;
  final int limit;

  /// Использовано и осталось в окне; `null` — счётчик на сервере недоступен.
  final int? used;
  final int? remaining;

  /// Начало следующего окна (UTC).
  final DateTime resetsAt;

  const FeatureLimit({
    required this.feature,
    required this.period,
    required this.limit,
    required this.used,
    required this.remaining,
    required this.resetsAt,
  });

  /// Лимит на момент [now]: если окно, в котором его прислал сервер, уже
  /// закончилось, — новое окно с полным остатком.
  FeatureLimit at(DateTime now) {
    if (now.isBefore(resetsAt)) return this;
    // Окна — по часам телефона (по ним же сервер считал resets_at)
    var next = resetsAt;
    while (!now.isBefore(next)) {
      final local = next.toLocal();
      next = switch (period) {
        LimitPeriod.day => DateTime(
            local.year, local.month, local.day + 1, local.hour, local.minute),
        LimitPeriod.month => DateTime(
            local.year, local.month + 1, local.day, local.hour, local.minute),
      }
          .toUtc();
    }
    return FeatureLimit(
      feature: feature,
      period: period,
      limit: limit,
      used: 0,
      remaining: limit,
      resetsAt: next,
    );
  }

  /// Лимит исчерпан в окне, действующем на момент [now].
  bool isExhaustedAt(DateTime now) => at(now).remaining == 0;

  /// Ещё один вызов в окне (успешный ответ сервера).
  FeatureLimit consumed(DateTime now) {
    final current = at(now);
    final used = current.used;
    final remaining = current.remaining;
    return FeatureLimit(
      feature: feature,
      period: period,
      limit: limit,
      used: used == null ? null : used + 1,
      remaining: remaining == null ? null : (remaining - 1).clamp(0, limit),
      resetsAt: current.resetsAt,
    );
  }

  /// Ответ `403 PLAN_LIMIT_REACHED`: остатка нет до [resetsAt].
  FeatureLimit exhausted(DateTime resetsAt) => FeatureLimit(
        feature: feature,
        period: period,
        limit: limit,
        used: limit,
        remaining: 0,
        resetsAt: resetsAt,
      );

  static FeatureLimit? fromJson(Map<String, dynamic> json) {
    final feature = PlanFeature.fromJson(json['feature']);
    final resetsAt = _parseDate(json['resets_at']);
    final limit = json['limit'];
    if (feature == null || resetsAt == null || limit is! int) return null;
    return FeatureLimit(
      feature: feature,
      period: LimitPeriod.fromJson(json['period']),
      limit: limit,
      used: json['used'] as int?,
      remaining: json['remaining'] as int?,
      resetsAt: resetsAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'feature': feature.code,
        'period': period.name,
        'limit': limit,
        'used': used,
        'remaining': remaining,
        'resets_at': resetsAt.toIso8601String(),
      };
}

/// Тариф и лимиты пользователя из профиля (`GET /auth/me`): последний
/// известный статус хранится на устройстве.
class PlanStatus {
  final SubscriptionStatus subscription;
  final Map<PlanFeature, FeatureLimit> limits;

  const PlanStatus({required this.subscription, this.limits = const {}});

  bool get isPro => subscription.isPro;

  /// Профиль с тарифом или `null`, если сервер его не прислал (ответ входа).
  static PlanStatus? fromProfile(Map<String, dynamic> data) {
    final subscription = data['subscription'];
    if (subscription is! Map<String, dynamic>) return null;
    final limits = <PlanFeature, FeatureLimit>{};
    final rawLimits = data['limits'];
    if (rawLimits is List) {
      for (final raw in rawLimits) {
        if (raw is! Map<String, dynamic>) continue;
        final limit = FeatureLimit.fromJson(raw);
        if (limit != null) limits[limit.feature] = limit;
      }
    }
    return PlanStatus(
      subscription: SubscriptionStatus.fromJson(subscription),
      limits: limits,
    );
  }

  PlanStatus copyWith({
    SubscriptionStatus? subscription,
    Map<PlanFeature, FeatureLimit>? limits,
  }) =>
      PlanStatus(
        subscription: subscription ?? this.subscription,
        limits: limits ?? this.limits,
      );

  PlanStatus withLimit(FeatureLimit limit) =>
      copyWith(limits: {...limits, limit.feature: limit});

  Map<String, dynamic> toJson() => {
        'subscription': subscription.toJson(),
        'limits': [for (final limit in limits.values) limit.toJson()],
      };
}

/// Ответ `403 PLAN_LIMIT_REACHED`: лимит функции на тарифе исчерпан.
class PlanLimitReached {
  final PlanFeature feature;
  final PlanCode plan;
  final int? limit;
  final LimitPeriod period;
  final DateTime? resetsAt;

  const PlanLimitReached({
    required this.feature,
    required this.plan,
    this.limit,
    this.period = LimitPeriod.day,
    this.resetsAt,
  });

  static const code = 'PLAN_LIMIT_REACHED';

  /// Детали из тела ошибки или `null`, если это другая ошибка.
  static PlanLimitReached? fromResponse(int? statusCode, dynamic body) {
    if (statusCode != 403 || body is! Map || body['code'] != code) return null;
    final details = body['details'];
    if (details is! Map) return null;
    final feature = PlanFeature.fromJson(details['feature']);
    if (feature == null) return null;
    final limit = details['limit'];
    return PlanLimitReached(
      feature: feature,
      plan: PlanCode.fromJson(details['plan']),
      limit: limit is int ? limit : null,
      period: LimitPeriod.fromJson(details['period']),
      resetsAt: _parseDate(details['resets_at']),
    );
  }
}
