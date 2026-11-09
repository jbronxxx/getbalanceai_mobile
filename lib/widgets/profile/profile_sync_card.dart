import 'package:flutter/material.dart';
import '../../cubits/profile/profile_cubit.dart';
import '../../theme/app_theme.dart';
import '../../utils/language_manager.dart';
import '../../theme/app_colors.dart';
import '../whole_words_text.dart';

/// Карточка статуса облачной синхронизации в стиле полированного жидкого стекла.
class ProfileSyncCard extends StatelessWidget {
  final bool isAuthenticated;
  final SyncStatus status;
  final VoidCallback onSyncPressed;

  /// Изменения, ещё не отправленные на сервер: пока они есть, карточка не
  /// пишет «синхронизировано».
  final int pendingCount;

  /// Записи, которые сервер не принял: пока они есть, под статусом видна
  /// строка, открывающая их список ([onRejectedPressed]).
  final int rejectedCount;
  final VoidCallback? onRejectedPressed;

  const ProfileSyncCard({
    super.key,
    required this.isAuthenticated,
    required this.status,
    required this.onSyncPressed,
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.onRejectedPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    String syncStatusText;
    IconData syncIcon = Icons.cloud_done_rounded;
    Color syncColor = AppColors.of(context).accentText;
    final bool isSyncing = status == SyncStatus.syncing;
    final bool hasPending = pendingCount > 0 &&
        (status == SyncStatus.idle || status == SyncStatus.success);

    if (hasPending) {
      syncStatusText = l10n.sync_pending(pendingCount);
      syncIcon = Icons.cloud_upload_rounded;
      syncColor = AppTheme.warningOrange;
    } else if (status == SyncStatus.noInternet) {
      syncStatusText = l10n.sync_no_internet;
      syncIcon = Icons.cloud_off_rounded;
      syncColor = colorScheme.outline;
    } else if (status == SyncStatus.syncing) {
      syncStatusText = l10n.syncing;
      syncIcon = Icons.sync_rounded;
      syncColor = AppTheme.warningOrange;
    } else if (status == SyncStatus.error) {
      syncStatusText = l10n.sync_error;
      syncIcon = Icons.error_outline_rounded;
      syncColor = colorScheme.error;
    } else if (status == SyncStatus.success) {
      syncStatusText = l10n.sync_updated_just_now;
      syncIcon = Icons.cloud_done_rounded;
      syncColor = AppColors.of(context).accentText;
    } else {
      syncStatusText = l10n.sync_synced;
    }

    final activeColor = isAuthenticated ? syncColor : colorScheme.outline;

    final glassBg = AppColors.of(context).cardGlassBackground;
    final glassBorder = AppColors.of(context).cardBorder;

    return Container(
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: glassBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isAuthenticated
              ? (!isSyncing ? onSyncPressed : null)
              : () => Navigator.of(context).pushNamed('/login'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: isAuthenticated && isSyncing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: syncColor,
                          ),
                        )
                      : Icon(
                          isAuthenticated ? syncIcon : Icons.cloud_outlined,
                          color: activeColor,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WholeWordsText(
                        l10n.sync_status,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      WholeWordsText(
                        isAuthenticated
                            ? syncStatusText
                            : l10n.cloud_backup_prompt,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isAuthenticated && rejectedCount > 0)
                        _RejectedLink(
                          count: rejectedCount,
                          onPressed: onRejectedPressed,
                        ),
                    ],
                  ),
                ),
                if (isAuthenticated)
                  Icon(Icons.sync_rounded,
                      color: AppColors.of(context).accentText, size: 20)
                else
                  Icon(Icons.chevron_right_rounded,
                      color: colorScheme.outline, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка «Сервер не принял: N ›» под статусом синхронизации. Свой
/// обработчик нажатия: тап по ней открывает список, а не запускает синк.
class _RejectedLink extends StatelessWidget {
  final int count;
  final VoidCallback? onPressed;

  const _RejectedLink({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        key: const ValueKey('sync_rejected_link'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.l10n.sync_rejected_count(count),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
