import 'package:flutter/material.dart';
import '../../cubits/profile/profile_cubit.dart';
import '../../theme/app_theme.dart';
import '../../utils/language_manager.dart';

/// Карточка статуса облачной синхронизации.
class ProfileSyncCard extends StatelessWidget {
  final bool isAuthenticated;
  final SyncStatus status;
  final VoidCallback onSyncPressed;

  const ProfileSyncCard({
    super.key,
    required this.isAuthenticated,
    required this.status,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    String syncStatusText;
    IconData syncIcon = Icons.cloud_done;
    Color syncColor = colorScheme.primary;
    final bool isSyncing = status == SyncStatus.syncing;

    if (status == SyncStatus.noInternet) {
      syncStatusText = l10n.sync_no_internet;
      syncIcon = Icons.cloud_off;
      syncColor = colorScheme.outline;
    } else if (status == SyncStatus.syncing) {
      syncStatusText = l10n.syncing;
      syncIcon = Icons.sync;
      syncColor = AppTheme.warningOrange;
    } else if (status == SyncStatus.error) {
      syncStatusText = l10n.sync_error;
      syncIcon = Icons.error_outline;
      syncColor = colorScheme.error;
    } else if (status == SyncStatus.success) {
      syncStatusText = l10n.sync_updated_just_now;
      syncIcon = Icons.cloud_done;
      syncColor = colorScheme.primary;
    } else {
      syncStatusText = l10n.sync_synced;
    }

    final activeColor = isAuthenticated ? syncColor : colorScheme.outline;

    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                    Text(
                      l10n.sync_status,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAuthenticated
                          ? syncStatusText
                          : l10n.cloud_backup_prompt,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAuthenticated)
                Icon(Icons.sync, color: colorScheme.primary, size: 20)
              else
                Icon(Icons.chevron_right, color: colorScheme.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
