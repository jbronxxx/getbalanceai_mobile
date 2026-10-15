import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';

/// Баннер уведомления о гостевом режиме (локальное хранилище без облака).
class GuestModeBanner extends StatelessWidget {
  const GuestModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bannerBg = isDark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerLow;
    final bannerBorder = colorScheme.outlineVariant;
    final iconColor = AppColors.of(context).accentText;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${context.l10n.guest_mode} (${context.l10n.cloud_not_connected.toLowerCase()})',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
