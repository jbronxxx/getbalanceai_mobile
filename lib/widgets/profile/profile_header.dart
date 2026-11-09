import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/utils.dart';
import '../one_line_label.dart';
import '../user_avatar.dart';
import 'edit_name_sheet.dart';

/// Виджет заголовка профиля с аватаром и информацией о пользователе.
class ProfileHeader extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? avatarUrl;
  final bool isAuthenticated;

  const ProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarUrl,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final effectiveAvatarUrl = avatarUrl ?? ApiService.instance.avatarUrl;

    final l10n = context.l10n;
    final initialLetter = isAuthenticated && userName.isNotEmpty
        ? userName[0].toUpperCase()
        : 'U';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.4),
                colorScheme.secondary.withValues(alpha: 0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: UserAvatar(
            radius: 48,
            avatarUrl: effectiveAvatarUrl,
            initials:
                isAuthenticated && userName.isNotEmpty ? initialLetter : null,
            defaultIcon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 12),
        if (isAuthenticated)
          // Имя с карандашом: нажатие открывает шторку смены имени
          Tooltip(
            message: l10n.edit_name_tooltip,
            child: InkWell(
              key: const ValueKey('profile_edit_name'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => EditNameSheet.show(context, name: userName),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text.rich(
                  TextSpan(
                    text: userName.isNotEmpty ? userName : l10n.local_profile,
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          )
        else
          Text(
            l10n.local_profile,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        if (isAuthenticated) ...[
          const SizedBox(height: 4),
          // Адрес — одно «слово»: при крупном шрифте длинный адрес слегка
          // уменьшается, а не переносится посреди («gmail.co / m»).
          OneLineLabel(
            userEmail,
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
      ],
    );
  }
}
