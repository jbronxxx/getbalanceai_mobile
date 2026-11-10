import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../utils/utils.dart';
import 'sheet_buttons.dart';
import 'whole_words_text.dart';

/// Закрывает всё приложение (вместе с открытыми шторками и диалогами)
/// экраном блокировки, пока [AppLockService.locked]. Под ним состояние
/// экранов сохраняется: после разблокировки пользователь там же, где был.
class AppLockGate extends StatelessWidget {
  final Widget child;
  final AppLockService? service;

  const AppLockGate({super.key, required this.child, this.service});

  @override
  Widget build(BuildContext context) {
    final lock = service ?? AppLockService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: lock.locked,
      builder: (context, locked, _) => Stack(
        children: [
          ExcludeSemantics(excluding: locked, child: child),
          if (locked) Positioned.fill(child: AppLockScreen(service: lock)),
        ],
      ),
    );
  }
}

/// Экран блокировки: сразу показывает системное окно отпечатка/PIN, после
/// отмены — кнопка «Разблокировать».
class AppLockScreen extends StatefulWidget {
  final AppLockService service;

  const AppLockScreen({super.key, required this.service});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final result = await widget.service.unlock(
      title: l10n.app_lock_prompt_title,
      reason: l10n.app_lock_reason,
    );
    if (!mounted) return;
    setState(() {
      _error = result == AppLockResult.lockedOut
          ? l10n.app_lock_too_many_attempts
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = _error;
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.lock_outline_rounded,
                  size: 64, color: colorScheme.primary),
              const SizedBox(height: 24),
              WholeWordsText(
                context.l10n.app_locked,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                WholeWordsText(
                  error,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.error),
                ),
              ],
              const Spacer(),
              SheetPrimaryButton(
                key: const ValueKey('app_unlock_button'),
                label: context.l10n.app_unlock,
                onPressed: _unlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
