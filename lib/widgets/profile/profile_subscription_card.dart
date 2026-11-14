import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../screens/paywall_screen.dart';
import '../../screens/subscription_actions.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../utils/utils.dart';
import '../whole_words_text.dart';

/// «Профиль → Подписка»: тариф, дата продления и остатки лимитов; на Free —
/// «Оформить Pro» (пейволл, гостю — с предложением войти), в Pro —
/// «Управлять в Google Play»; после входа — «Восстановить покупки».
///
/// Остатки меняются на сервере (другие устройства, генерация отчёта),
/// поэтому при показе вкладки профиль перечитывается — не чаще
/// [refreshInterval].
class ProfileSubscriptionCard extends StatefulWidget {
  final bool isAuthenticated;
  final ApiService? api;

  const ProfileSubscriptionCard({
    super.key,
    required this.isAuthenticated,
    this.api,
  });

  static const refreshInterval = Duration(minutes: 1);

  @override
  State<ProfileSubscriptionCard> createState() =>
      _ProfileSubscriptionCardState();
}

class _ProfileSubscriptionCardState extends State<ProfileSubscriptionCard> {
  late final ApiService _api = widget.api ?? ApiService.instance;
  DateTime? _refreshedAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Зависимость от TickerMode: вызов повторится при показе вкладки
    final visible = TickerMode.valuesOf(context).enabled;
    final last = _refreshedAt;
    final now = DateTime.now();
    if (!visible ||
        !widget.isAuthenticated ||
        (last != null &&
            now.difference(last) < ProfileSubscriptionCard.refreshInterval)) {
      return;
    }
    _refreshedAt = now;
    _api.auth.refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlanStatus?>(
      valueListenable: _api.subscription.status,
      builder: (context, status, _) => _buildCard(context, status),
    );
  }

  Widget _buildCard(BuildContext context, PlanStatus? status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final signedIn = widget.isAuthenticated;
    final subscription = signedIn
        ? status?.subscription ?? SubscriptionStatus.free
        : SubscriptionStatus.free;
    final details = signedIn
        ? [
            _term(context, subscription),
            for (final feature in PlanFeature.values)
              _limitLine(context, _api.subscription.limit(feature)),
          ].nonNulls.toList()
        : const <String>[];

    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    );
    final divider = Divider(height: 1, thickness: 1, color: colors.cardDivider);

    Widget action(String key, String title, VoidCallback onTap,
            {bool external = false}) =>
        ListTile(
          key: ValueKey(key),
          title: WholeWordsText(title, style: titleStyle),
          trailing: external
              ? Icon(Icons.open_in_new, size: 20, color: colorScheme.outline)
              : null,
          onTap: onTap,
        );

    return Container(
      decoration: BoxDecoration(
        color: colors.cardGlassBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            ListTile(
              key: const ValueKey('subscription_plan_tile'),
              title: WholeWordsText(l10n.subscription_plan, style: titleStyle),
              subtitle: details.isEmpty
                  ? null
                  : WholeWordsText(
                      details.join('\n'),
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline, height: 1.4),
                    ),
              trailing: Text(
                subscription.isPro ? l10n.plan_name_pro : l10n.plan_name_free,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: subscription.isPro
                      ? colors.accentText
                      : colorScheme.outline,
                ),
              ),
            ),
            divider,
            if (subscription.isPro)
              action(
                'subscription_manage',
                l10n.subscription_manage,
                () => SubscriptionActions.manage(context),
                external: true,
              )
            else
              action(
                'subscription_get_pro',
                l10n.subscription_get_pro,
                () => PaywallScreen.show(context),
              ),
            if (signedIn) ...[
              divider,
              action(
                'subscription_restore',
                l10n.restore_purchases,
                () => SubscriptionActions.restore(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Срок Pro: пробный, продление или окончание доступа.
  static String? _term(BuildContext context, SubscriptionStatus subscription) {
    final expiresAt = subscription.expiresAt;
    if (!subscription.isPro || expiresAt == null) return null;
    final date = LanguageManager.formatDayMonthYear(expiresAt.toLocal());
    final l10n = context.l10n;
    if (subscription.isTrial) return l10n.subscription_trial_until(date);
    return subscription.willRenew
        ? l10n.subscription_renews_on(date)
        : l10n.subscription_ends_on(date);
  }

  static String? _limitLine(BuildContext context, FeatureLimit? limit) {
    final remaining = limit?.remaining;
    if (limit == null || remaining == null) return null;
    final l10n = context.l10n;
    return switch ((limit.feature, limit.period)) {
      (PlanFeature.aiReport, LimitPeriod.month) =>
        l10n.subscription_limit_ai_report_month(remaining, limit.limit),
      (PlanFeature.aiReport, LimitPeriod.day) =>
        l10n.subscription_limit_ai_report_day(remaining, limit.limit),
      (PlanFeature.voice, _) =>
        l10n.subscription_limit_voice_day(remaining, limit.limit),
    };
  }
}
