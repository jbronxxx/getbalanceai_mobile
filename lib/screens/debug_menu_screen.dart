import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../config/environment.dart';
import '../utils/app_logger.dart';
import '../utils/language_manager.dart';
import '../services/services.dart';

/// Экран меню отладки для разработчиков и QA-тестирования.
class DebugMenuScreen extends StatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  State<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends State<DebugMenuScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final version = await AppInfoService.instance.getVersionString();
    if (!mounted) return;
    setState(() {
      _appVersion = version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debug_menu_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.debug_environment,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<Environment>(
            value: EnvironmentConfig.current,
            isExpanded: true,
            items: Environment.values.map((env) {
              return DropdownMenuItem(
                value: env,
                child: Text(env.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) async {
              if (val != null) {
                await EnvironmentConfig.setEnvironment(val);
                setState(() {});
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.debug_environment_changed(val.name.toUpperCase()),
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(height: 32),
          Text(
            l10n.debug_app_info,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.debug_version(_appVersion),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.debug_base_url(EnvironmentConfig.baseUrl),
            style: textTheme.bodyMedium,
          ),
          const Divider(height: 32),
          Text(
            l10n.debug_tools,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TalkerScreen(talker: talker),
                ),
              );
            },
            child: Text(l10n.debug_open_logs),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await ApiService.instance.clearAllUserData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.debug_cache_cleared)),
              );
            },
            child: Text(l10n.debug_clear_cache),
          ),
        ],
      ),
    );
  }
}
