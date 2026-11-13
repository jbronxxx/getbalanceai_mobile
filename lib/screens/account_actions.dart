import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/profile/profile_cubit.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Выход и удаление аккаунта с подтверждением — общие для «Профиля» и экрана
/// новой версии условий. Нужен [ProfileCubit] выше по дереву (выход).
abstract final class AccountActions {
  /// Выход стирает данные аккаунта с устройства, поэтому сначала пробуем
  /// выгрузить неотправленные изменения; если не вышло — предупреждаем,
  /// сколько изменений пропадёт.
  static Future<void> logout(BuildContext context) async {
    final cubit = context.read<ProfileCubit>();
    final navigator = Navigator.of(context);

    var unsynced = 0;
    if (cubit.hasChangesToUpload) {
      showLoadingDialog(context, context.l10n.syncing);
      unsynced = await cubit.prepareLogout();
      navigator.pop();
      if (!context.mounted) return;
    }

    final confirm = await AppAlerts.showConfirmDialog(
      context,
      title: context.l10n.logout_confirm_title,
      message: unsynced > 0
          ? context.l10n.logout_unsynced_warning(unsynced)
          : context.l10n.logout_confirm_desc,
      confirmText: context.l10n.logout,
      cancelText: context.l10n.cancel,
      isDestructive: unsynced > 0,
    );

    if (confirm != true || !context.mounted) return;

    showLoadingDialog(context, context.l10n.logging_out);
    // О выходе AuthCubit узнаёт из authStream внутри logout(), поэтому
    // экран может успеть размонтироваться — диалог закрываем через
    // заранее полученный navigator.
    await cubit.logout();
    navigator.pop();
    if (!context.mounted) return;
    AppAlerts.info(context, context.l10n.logout_info);
  }

  static Future<void> deleteAccount(BuildContext context) async {
    final confirm = await AppAlerts.showConfirmDialog(
      context,
      title: context.l10n.delete_account_title,
      message: context.l10n.delete_account_confirm,
      confirmText: context.l10n.delete_account_confirm_btn,
      cancelText: context.l10n.cancel,
      isDestructive: true,
    );

    if (confirm != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    showLoadingDialog(context, context.l10n.deleting);
    try {
      // Выход и очистку данных выполняет сам deleteAccount().
      await ApiService.instance.deleteAccount();
      navigator.pop();
    } catch (e) {
      navigator.pop();
      if (context.mounted) {
        AppErrorHandler.show(context, e,
            title: context.l10n.delete_account_error);
      }
    }
  }

  /// Неотменяемый диалог ожидания с [message] (выгрузка, выход, удаление).
  static void showLoadingDialog(BuildContext context, String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          AppColors.shadowBase.withValues(alpha: isDark ? 0.70 : 0.40),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: GlassContainer(
              borderRadius: 28,
              blurSigma: 18,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary
                          .withValues(alpha: isDark ? 0.16 : 0.12),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: AppColors.of(context).accentText,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
