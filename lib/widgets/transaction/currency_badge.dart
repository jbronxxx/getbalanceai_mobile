import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../../theme/app_colors.dart';

/// Бейдж с кодом валюты для суффикса поля суммы. С [onTap] открывает выбор
/// валюты, без него только показывает валюту (лимиты — в базовой валюте).
///
/// С [onTap] нажатие срабатывает во всей полосе высотой
/// [kMinInteractiveDimension] вокруг бейджа, а не только на нём самом.
class CurrencyBadge extends StatelessWidget {
  final Currency currency;
  final VoidCallback? onTap;

  const CurrencyBadge({super.key, required this.currency, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final badge = Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.highlightBase.withValues(alpha: 0.10)
                  : colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? AppColors.highlightBase.withValues(alpha: 0.20)
                    : colorScheme.primary.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Text(
              currency.code,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.of(context).accentText,
              ),
            ),
          ),
        ),
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: UnconstrainedBox(child: badge),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(
      key: const ValueKey('currency_badge_tap_area'),
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: content,
    );
  }
}
