import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/utils.dart';

/// Превью AI-советов для гостя: размытые примеры советов и поверх — карточка
/// с объяснением и кнопкой входа. Показывает, что именно получит пользователь,
/// вместо пустого экрана с текстом.
class InsightsGuestPreview extends StatelessWidget {
  final VoidCallback onLogin;

  const InsightsGuestPreview({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final samples = [
      l10n.insight_demo_1,
      l10n.insight_demo_2,
      l10n.insight_demo_3,
    ];

    // Оба слоя задают размер стека: при крупном шрифте карточка входа может
    // оказаться выше примеров и не должна обрезаться.
    return Stack(
      alignment: Alignment.center,
      children: [
        // Примеры — только декорация: не читаются экранным чтецом и не
        // перехватывают нажатия.
        ExcludeSemantics(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Column(
                children: [
                  for (final text in samples) _SampleCard(text: text),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _LoginCallout(onLogin: onLogin),
        ),
      ],
    );
  }
}

class _SampleCard extends StatelessWidget {
  final String text;

  const _SampleCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCallout extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginCallout({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.insights_guest_title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.insight_login_hint,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('insights_guest_login'),
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(context.l10n.insights_guest_login_btn),
            ),
          ),
        ],
      ),
    );
  }
}
