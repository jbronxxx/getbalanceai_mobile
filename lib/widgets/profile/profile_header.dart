import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/utils.dart';

/// Виджет заголовка профиля с аватаром и информацией о пользователе.
class ProfileHeader extends StatelessWidget {
  final String userName;
  final String userEmail;
  final bool isAuthenticated;

  const ProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final avatarUrl = ApiService.instance.avatarUrl;

    final l10n = context.l10n;
    final initialLetter = isAuthenticated && userName.isNotEmpty
        ? userName[0].toUpperCase()
        : 'U';

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? (isAuthenticated
                  ? Text(
                      initialLetter,
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.person_outline_rounded,
                      size: 48,
                      color: colorScheme.primary,
                    ))
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          isAuthenticated && userName.isNotEmpty
              ? userName
              : l10n.local_profile,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        if (isAuthenticated) ...[
          const SizedBox(height: 4),
          Text(
            userEmail.isNotEmpty ? userEmail : '',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.local_storage_warning,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
