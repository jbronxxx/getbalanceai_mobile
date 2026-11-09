import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../utils/utils.dart';
import '../user_avatar.dart';
import '../../theme/app_colors.dart';

/// Действие в шапке дашборда: «Войти» для гостя, аватар — для вошедшего.
///
/// Отступ от правого края экрана — 16 dp; у аватара зона нажатия
/// [kMinInteractiveDimension] шире самого круга, поэтому его внешний отступ
/// меньше на эту разницу.
class DashboardAccountAction extends StatelessWidget {
  static const double _edgeInset = 16;
  static const double _avatarSize = 36;

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
          return Padding(
            padding: const EdgeInsets.only(right: _edgeInset),
            child: TextButton(
              onPressed: onLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.of(context).accentText,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(
            right: _edgeInset - (kMinInteractiveDimension - _avatarSize) / 2,
          ),
          child: Semantics(
            button: true,
            label: context.l10n.profile,
            onTap: onOpenProfile,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('dashboard_profile_avatar'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenProfile,
              child: SizedBox.square(
                dimension: kMinInteractiveDimension,
                child: Center(
                  child: UserAvatar(
                    radius: _avatarSize / 2,
                    avatarUrl: ApiService.instance.avatarUrl,
                    defaultIcon: Icons.person,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
