import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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

    final initialLetter = isAuthenticated && userName.isNotEmpty
        ? userName[0].toUpperCase()
        : (isAuthenticated ? 'U' : '?');

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  initialLetter,
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          isAuthenticated && userName.isNotEmpty ? userName : 'Guest User',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isAuthenticated && userEmail.isNotEmpty
              ? userEmail
              : 'cloud.offline@getbalance.ai',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
