import 'package:flutter/material.dart';
import '../utils/utils.dart';
import '../theme/app_colors.dart';

/// Виджет аватара пользователя с безопасной сетевой загрузкой
/// и отказоустойчивым отображением инициалов/иконки при сбоях сети.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final String? initials;
  final IconData defaultIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 20,
    this.initials,
    this.defaultIcon = Icons.person,
    this.backgroundColor,
    this.foregroundColor,
  });

  Widget _buildFallback(BuildContext context, Color fgColor, Color bgColor) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: (initials != null && initials!.isNotEmpty)
          ? Text(
              initials!,
              style: TextStyle(
                fontSize: radius * 0.85,
                fontWeight: FontWeight.bold,
                color: fgColor,
              ),
            )
          : Icon(
              defaultIcon,
              size: radius * 1.1,
              color: fgColor,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor =
        backgroundColor ?? colorScheme.primary.withValues(alpha: 0.1);
    final fgColor = foregroundColor ?? AppColors.of(context).accentText;
    final size = radius * 2;

    final url = avatarUrl;
    if (url == null || url.trim().isEmpty) {
      return _buildFallback(context, fgColor, bgColor);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildFallback(context, fgColor, bgColor),
          Image.network(
            url,
            key: ValueKey(url),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.w('Avatar network load error for $url: $error');
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
