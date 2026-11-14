import 'package:flutter/material.dart';

import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'account_actions.dart';

/// Покупка, восстановление и управление подпиской — общие для пейволла,
/// «Профиль → Подписка» и удаления аккаунта.
///
/// Магазин только принимает оплату: Pro включает сервер по данным RevenueCat,
/// поэтому после покупки и восстановления статус запрашивается у него
/// (`POST /subscriptions/refresh`), а лимиты — с профилем.
abstract final class SubscriptionActions {
  /// Покупка [option]. `true` — магазин принял оплату, пейволл можно закрыть.
  static Future<bool> purchase(
    BuildContext context,
    ProOption option, {
    PurchaseService? store,
    ApiService? api,
  }) async {
    final l10n = context.l10n;
    final outcome = await (store ?? PurchaseService.instance).purchase(option);
    if (!context.mounted) return false;
    switch (outcome) {
      case StoreOutcome.cancelled:
        return false;
      case StoreOutcome.pending:
        AppAlerts.info(context, l10n.subscription_payment_pending);
        return false;
      case StoreOutcome.otherAccount:
        AppAlerts.warning(context, l10n.subscription_other_account);
        return false;
      case StoreOutcome.failed:
        AppAlerts.error(context, l10n.subscription_purchase_failed);
        return false;
      case StoreOutcome.completed:
        final pro = await _checkOnServer(context, api ?? ApiService.instance);
        if (context.mounted) {
          if (pro) {
            AppAlerts.success(context, l10n.subscription_activated);
          } else {
            // Вебхук RevenueCat ещё не дошёл или сервер не достучался до него
            AppAlerts.info(context, l10n.subscription_pending_sync);
          }
        }
        return true;
    }
  }

  /// «Восстановить покупки»: подписка этого аккаунта Google Play переходит к
  /// вошедшему пользователю, если не привязана к другому. `true` — Pro
  /// активен.
  static Future<bool> restore(
    BuildContext context, {
    PurchaseService? store,
    ApiService? api,
  }) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    AccountActions.showLoadingDialog(context, l10n.subscription_checking);
    final outcome = await (store ?? PurchaseService.instance).restore();
    final pro = outcome == StoreOutcome.completed &&
        await _refresh(api ?? ApiService.instance);
    navigator.pop();
    if (!context.mounted) return pro;
    switch (outcome) {
      case StoreOutcome.cancelled:
        break;
      case StoreOutcome.pending:
        AppAlerts.info(context, l10n.subscription_payment_pending);
      case StoreOutcome.otherAccount:
        AppAlerts.warning(context, l10n.subscription_other_account);
      case StoreOutcome.failed:
        AppAlerts.error(context, l10n.subscription_restore_failed);
      case StoreOutcome.completed:
        if (pro) {
          AppAlerts.success(context, l10n.subscription_restored);
        } else {
          AppAlerts.info(context, l10n.subscription_restore_none);
        }
    }
    return pro;
  }

  /// Страница подписок в Google Play: отмена, смена периода, оплата.
  static Future<void> manage(
    BuildContext context, {
    PurchaseService? store,
    Future<bool> Function(Uri uri) launcher = openExternalUrl,
  }) async {
    final l10n = context.l10n;
    var opened = false;
    try {
      final uri = await (store ?? PurchaseService.instance).managementUrl();
      opened = await launcher(uri);
    } catch (e, stack) {
      AppLogger.e('[Subscription] Не удалось открыть Google Play', e, stack);
    }
    if (!opened && context.mounted) {
      AppAlerts.error(context, l10n.open_link_error);
    }
  }

  static Future<bool> _checkOnServer(
      BuildContext context, ApiService api) async {
    final navigator = Navigator.of(context);
    AccountActions.showLoadingDialog(
        context, context.l10n.subscription_checking);
    final pro = await _refresh(api);
    navigator.pop();
    return pro;
  }

  /// Статус подписки с сервера, затем профиль — лимиты нового тарифа.
  /// Ошибки сервера не мешают: вебхук обновит статус позже.
  static Future<bool> _refresh(ApiService api) async {
    try {
      await api.subscription.refresh();
    } catch (e) {
      AppLogger.w('[Subscription] Не удалось обновить статус подписки: $e');
    }
    await api.auth.refreshProfile();
    return api.subscription.isPro;
  }
}
