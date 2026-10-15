import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../user_avatar.dart';
import '../../theme/app_colors.dart';

/// Действие в шапке дашборда: «Войти» для гостя, аватар — для вошедшего.
class DashboardAccountAction extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onOpenProfile;

  const DashboardAccountAction({
    super.key,
    required this.onLogin,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<bool>(
      stream: ApiService.instance.authStream,
      builder: (context, _) {
        if (!ApiService.instance.isAuthenticated) {
          return TextButton(
            onPressed: onLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).accentText,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.l10n.login_btn_short,
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.of(context).accentText,
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: onOpenProfile,
          child: UserAvatar(
            radius: 18,
            avatarUrl: ApiService.instance.avatarUrl,
            defaultIcon: Icons.person,
          ),
        );
      },
    );
  }
}
