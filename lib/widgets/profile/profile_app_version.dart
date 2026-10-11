import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/environment.dart';
import '../../screens/debug_menu_screen.dart';
import '../../utils/language_manager.dart';

/// Виджет отображения версии приложения с поддержкой активации Debug Menu по тапам.
class ProfileAppVersion extends StatefulWidget {
  final String appVersion;

  const ProfileAppVersion({
    super.key,
    required this.appVersion,
  });

  @override
  State<ProfileAppVersion> createState() => _ProfileAppVersionState();
}

class _ProfileAppVersionState extends State<ProfileAppVersion> {
  int _debugTapCount = 0;
  Timer? _tapResetTimer;

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!EnvironmentConfig.debugMenuEnabled) return;

    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _debugTapCount = 0;
        });
      }
    });

    _debugTapCount++;

    if (_debugTapCount >= 5) {
      _tapResetTimer?.cancel();
      _debugTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DebugMenuScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          context.l10n.version_label(widget.appVersion),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
