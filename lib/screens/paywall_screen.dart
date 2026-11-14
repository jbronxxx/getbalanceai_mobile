import 'dart:async';

import 'package:flutter/material.dart';

import '../config/legal_links.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'subscription_actions.dart';

/// Откуда открыт пейволл: от причины зависит первая строка экрана.
enum PaywallTrigger {
  /// «Профиль → Подписка».
  subscription,

  /// Второй ИИ-отчёт за месяц на Free.
  aiReport,

  /// Голосовой ввод сверх суточного лимита Free.
  voice,

  /// «Выгрузить отчёт» на Free.
  export;

  static PaywallTrigger fromFeature(PlanFeature feature) => switch (feature) {
        PlanFeature.aiReport => PaywallTrigger.aiReport,
        PlanFeature.voice => PaywallTrigger.voice,
      };
}

/// Пейволл Pro: один полноэкранный экран для всех точек входа. Показывается
/// только при упоре в лимит Free и из «Профиль → Подписка».
///
/// Сверху — «Не сейчас» (и системное «Назад»), дальше прокручиваются Pro
/// против Free и выбор периода; главная кнопка, условия подписки и ссылки
/// закреплены внизу. Цены и пробный период — из магазина через RevenueCat.
/// Гость не покупает: вместо оплаты — «Войдите, чтобы оформить Pro».
class PaywallScreen extends StatefulWidget {
  final PaywallTrigger trigger;

  /// Когда лимит Free снова будет доступен (для [PaywallTrigger.aiReport]).
  final DateTime? resetsAt;

  final PurchaseService? store;
  final ApiService? api;

  const PaywallScreen({
    super.key,
    this.trigger = PaywallTrigger.subscription,
    this.resetsAt,
    this.store,
    this.api,
  });

  static Future<void> show(
    BuildContext context, {
    PaywallTrigger trigger = PaywallTrigger.subscription,
    DateTime? resetsAt,
  }) =>
      open(Navigator.of(context, rootNavigator: true),
          trigger: trigger, resetsAt: resetsAt);

  /// Для вызова, когда контекст закрывается (шторка голосового ввода).
  static Future<void> open(
    NavigatorState navigator, {
    PaywallTrigger trigger = PaywallTrigger.subscription,
    DateTime? resetsAt,
  }) =>
      navigator.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(trigger: trigger, resetsAt: resetsAt),
      ));

  /// Пейволл по ответу `403 PLAN_LIMIT_REACHED`.
  static Future<void> showForLimit(
    BuildContext context,
    PlanLimitReached reached,
  ) =>
      show(context,
          trigger: PaywallTrigger.fromFeature(reached.feature),
          resetsAt: reached.resetsAt);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final PurchaseService _store = widget.store ?? PurchaseService.instance;
  late final ApiService _api = widget.api ?? ApiService.instance;
  late final bool _signedIn = _api.isAuthenticated;

  List<ProOption>? _options;
  bool _loadFailed = false;
  bool _purchasing = false;
  ProPeriod _period = ProPeriod.year;

  @override
  void initState() {
    super.initState();
    if (_signedIn) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _options = null;
      _loadFailed = false;
    });
    List<ProOption> options = const [];
    try {
      if (_store.isAvailable) options = await _store.loadOptions();
    } catch (e) {
      AppLogger.w('[Paywall] Не удалось загрузить предложение: $e');
    }
    if (!mounted) return;
    setState(() {
      _loadFailed = options.isEmpty;
      _options = options.isEmpty ? null : options;
      if (options.every((o) => o.period != _period)) {
        _period = options.isEmpty ? ProPeriod.year : options.first.period;
      }
    });
  }

  ProOption? get _selected {
    final options = _options;
    if (options == null) return null;
    for (final option in options) {
      if (option.period == _period) return option;
    }
    return null;
  }

  /// Скидка годовой подписки к помесячной оплате, %; `null` — не посчитать.
  int? get _yearDiscount {
    final options = _options ?? const [];
    double? month, year;
    for (final option in options) {
      if (option.period == ProPeriod.month) month = option.price;
      if (option.period == ProPeriod.year) year = option.price;
    }
    if (month == null || year == null || month <= 0) return null;
    final percent = ((1 - year / (month * 12)) * 100).floor();
    return percent > 0 ? percent : null;
  }

  Future<void> _purchase(ProOption option) async {
    setState(() => _purchasing = true);
    final done = await SubscriptionActions.purchase(context, option,
        store: _store, api: _api);
    if (!mounted) return;
    setState(() => _purchasing = false);
    if (done) Navigator.of(context).pop();
  }

  Future<void> _restore() async {
    final pro =
        await SubscriptionActions.restore(context, store: _store, api: _api);
    if (pro && mounted) Navigator.of(context).pop();
  }

  void _signIn() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed('/login');
  }

  String _price(ProOption option) => switch (option.period) {
        ProPeriod.month => context.l10n.paywall_price_month(option.priceString),
        ProPeriod.year => context.l10n.paywall_price_year(option.priceString),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: TextButton(
                  key: const ValueKey('paywall_not_now'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.outline,
                  ),
                  child: Text(l10n.paywall_not_now),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WholeWordsText(
                      l10n.paywall_title,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    WholeWordsText(
                      _reason(context) ?? l10n.paywall_subtitle,
                      key: const ValueKey('paywall_reason'),
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PlanBlock(
                      title: l10n.plan_name_pro,
                      highlighted: true,
                      lines: [
                        l10n.plan_feature_ai_report_daily(
                            PlanCatalog.proAiReportsPerDay),
                        l10n.plan_feature_voice_daily(
                            PlanCatalog.proVoicePerDay),
                        l10n.plan_feature_export,
                        l10n.plan_feature_basics,
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PlanBlock(
                      title: l10n.plan_name_free,
                      lines: [
                        l10n.plan_feature_ai_report_monthly(
                            _freeLimit(PlanFeature.aiReport)),
                        l10n.plan_feature_voice_daily(
                            _freeLimit(PlanFeature.voice)),
                        l10n.plan_feature_basics,
                      ],
                    ),
                    if (_signedIn && !_loadFailed) ...[
                      const SizedBox(height: 24),
                      _buildOptions(context),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: _buildFooter(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Лимит Free из профиля (сервер — источник правды), иначе из каталога.
  int _freeLimit(PlanFeature feature) {
    final status = _api.subscription.status.value;
    final limit =
        status != null && !status.isPro ? status.limits[feature]?.limit : null;
    return limit ??
        switch (feature) {
          PlanFeature.aiReport => PlanCatalog.freeAiReportsPerMonth,
          PlanFeature.voice => PlanCatalog.freeVoicePerDay,
        };
  }

  String? _reason(BuildContext context) {
    final l10n = context.l10n;
    final resetsAt = widget.resetsAt;
    return switch (widget.trigger) {
      PaywallTrigger.subscription => null,
      PaywallTrigger.aiReport => l10n.paywall_reason_ai_report(nonBreaking(
          LanguageManager.formatDayMonthYear(
              (resetsAt ?? _nextMonthStart()).toLocal()))),
      PaywallTrigger.voice => l10n.paywall_reason_voice,
      PaywallTrigger.export => l10n.paywall_reason_export,
    };
  }

  static DateTime _nextMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1);
  }

  Widget _buildOptions(BuildContext context) {
    final options = _options;
    if (options == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final discount = _yearDiscount;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, option) in options.indexed) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(
            child: _PeriodOption(
              key: ValueKey('paywall_period_${option.period.name}'),
              title: option.period == ProPeriod.month
                  ? context.l10n.paywall_period_month
                  : context.l10n.paywall_period_year,
              price: _price(option),
              badge: option.period == ProPeriod.year && discount != null
                  ? context.l10n.paywall_year_discount(discount)
                  : null,
              selected: option.period == _period,
              onTap: _purchasing
                  ? null
                  : () => setState(() => _period = option.period),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.outline,
      height: 1.35,
    );

    if (!_signedIn) {
      return SheetPrimaryButton(
        key: const ValueKey('paywall_sign_in'),
        label: l10n.paywall_sign_in,
        onPressed: _signIn,
      );
    }

    final option = _selected;
    final trialDays = option?.trialDays;
    final Widget button;
    if (_loadFailed) {
      button = SheetPrimaryButton(
        key: const ValueKey('paywall_retry'),
        label: l10n.paywall_retry,
        onPressed: _load,
      );
    } else {
      button = SheetPrimaryButton(
        key: const ValueKey('paywall_buy'),
        label: trialDays != null
            ? l10n.paywall_start_trial(trialDays)
            : l10n.paywall_subscribe,
        busy: _purchasing,
        onPressed:
            option == null || _purchasing ? null : () => _purchase(option),
      );
    }

    final link = TextButton.styleFrom(
      foregroundColor: colorScheme.outline,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: theme.textTheme.bodySmall
          ?.copyWith(decoration: TextDecoration.underline),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Цены не загрузились: причина — над «Повторить», а не в прокрутке,
        // где её не видно на небольшом экране.
        if (_loadFailed) ...[
          WholeWordsText(
            l10n.paywall_prices_unavailable,
            key: const ValueKey('paywall_prices_unavailable'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
        button,
        if (option != null) ...[
          const SizedBox(height: 8),
          WholeWordsText(
            trialDays != null
                ? l10n.paywall_terms_trial(trialDays, _price(option))
                : l10n.paywall_terms(_price(option)),
            key: const ValueKey('paywall_terms'),
            textAlign: TextAlign.center,
            style: small,
          ),
        ],
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              style: link,
              onPressed: () => openLegalPage(context, LegalPage.terms),
              child: Text(l10n.terms_of_use_title),
            ),
            TextButton(
              style: link,
              onPressed: () => openLegalPage(context, LegalPage.privacy),
              child: Text(l10n.privacy_policy_title),
            ),
            TextButton(
              key: const ValueKey('paywall_restore'),
              style: link,
              onPressed: _purchasing ? null : _restore,
              child: Text(l10n.restore_purchases),
            ),
          ],
        ),
      ],
    );
  }
}

/// Тариф и его возможности текстом; Pro выделен рамкой.
class _PlanBlock extends StatelessWidget {
  final String title;
  final List<String> lines;
  final bool highlighted;

  const _PlanBlock({
    required this.title,
    required this.lines,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colors.cardGlassBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? colorScheme.primary : colors.cardBorder,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WholeWordsText(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlighted ? colors.accentText : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: WholeWordsText('· $line', style: textStyle),
            ),
        ],
      ),
    );
  }
}

/// Выбор периода: название, цена из магазина и скидка года.
class _PeriodOption extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;

  const _PeriodOption({
    super.key,
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final badge = this.badge;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colors.cardGlassBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? colorScheme.primary : colors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OneLineLabel(
                        title,
                        alignment: AlignmentDirectional.centerStart,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Text(
                        badge,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.accentText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                WholeWordsText(
                  price,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
