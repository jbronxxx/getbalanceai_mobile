import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/profile/profile_cubit.dart';
import '../cubits/auth/auth_cubit.dart';
import 'debug_menu_screen.dart';
import '../config/environment.dart';

/// Экран профиля пользователя, совмещенный с настройками приложения.
class ProfileScreen extends StatelessWidget {
  final String userEmail;
  final String userName;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(),
      child: _ProfileScreenView(
        userEmail: userEmail,
        userName: userName,
        onLogout: onLogout,
      ),
    );
  }
}

class _ProfileScreenView extends StatefulWidget {
  final String userEmail;
  final String userName;
  final VoidCallback onLogout;

  const _ProfileScreenView({
    required this.userEmail,
    required this.userName,
    required this.onLogout,
  });

  @override
  State<_ProfileScreenView> createState() => _ProfileScreenViewState();
}

class _ProfileScreenViewState extends State<_ProfileScreenView> {
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;
  String _appVersion = '';
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final version = await AppInfoService.instance.getVersionString();
    if (mounted) {
      setState(() {
        _appVersion = version;
      });
    }
  }

  Future<void> _loadSettings() async {
    final notifications =
        await PreferencesService.instance.getNotificationsEnabled();
    final darkMode = await PreferencesService.instance.getDarkMode();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _isDarkMode = darkMode;
      });
    }
  }

  void _handleSyncState(BuildContext context, ProfileState state) {
    if (state.syncStatus == SyncStatus.noInternet) {
      AppAlerts.noInternet(context);
    } else if (state.syncStatus == SyncStatus.success) {
      AppAlerts.success(context, context.l10n.sync_success);
    } else if (state.syncStatus == SyncStatus.error) {
      AppErrorHandler.show(context, state.syncError, title: context.l10n.cloud);
    }
  }

  /// Выбор валюты в модальном окне.
  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            top: 10,
            left: 24,
            right: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                context.l10n.select_currency,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...Currency.values.map((c) => _buildCurrencyOption(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(Currency currency) {
    return ValueListenableBuilder<Currency>(
      valueListenable: CurrencyFormatter.currencyNotifier,
      builder: (context, currentCurrency, child) {
        final isSelected = currentCurrency == currency;
        final label = '${currency.localizedSymbol} — ${currency.localizedName}';
        return ListTile(
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            CurrencyFormatter.setCurrency(currency);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// Выбор языка в модальном окне.
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            top: 10,
            left: 24,
            right: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                context.l10n.select_language,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...AppLanguage.values.map((l) => _buildLanguageOption(l)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(AppLanguage lang) {
    final isSelected = LanguageManager.currentLanguage == lang;
    final label = '${lang.flag}   ${lang.displayName}';
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        LanguageManager.setLanguage(lang);
        Navigator.pop(context);
        setState(() {}); // Обновляем локальное состояние
      },
    );
  }

  void _handleLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final cubit = context.read<ProfileCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logout_confirm_title),
        content: Text(context.l10n.logout_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog('Выход...');
    await cubit.logout();
    if (!mounted) return;
    Navigator.pop(context); // закрыть лоадер

    widget.onLogout();
    AppAlerts.info(context, context.l10n.logout_info);
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление аккаунта'),
        content: const Text(
            'Вы уверены, что хотите навсегда удалить свой аккаунт и все связанные с ним данные? Это действие невозможно отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _showLoadingDialog('Удаление...');
      try {
        await ApiService.instance.deleteAccount();
        if (mounted) {
          Navigator.pop(context); // закрыть лоадер
          widget.onLogout();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // закрыть лоадер
          AppErrorHandler.show(context, e, title: 'Ошибка удаления');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = Theme.of(context).colorScheme.primary;

    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (previous, current) =>
          previous.syncStatus != current.syncStatus,
      listener: (context, state) {
        _handleSyncState(context, state);
      },
      builder: (context, state) {
        final isAuthenticated =
            context.watch<AuthCubit>().state is Authenticated;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text(context.l10n.profile,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: 16.0 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                children: [
                  _buildProfileHeader(primaryTeal, isAuthenticated),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context.l10n.cloud),
                  _buildSyncCard(
                      primaryTeal, isAuthenticated, state.syncStatus),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context.l10n.interface),
                  _buildSettingsCard(primaryTeal),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: isAuthenticated
                        ? TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout),
                            label: Text(context.l10n.logout,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          )
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryTeal,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _handleLogin,
                            icon: const Icon(Icons.login),
                            label: Text(context.l10n.login_or_register,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                  ),
                  if (isAuthenticated) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade500,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: _handleDeleteAccount,
                        child: const Text('Удалить аккаунт',
                            style: TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildAppVersion(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppVersion(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!EnvironmentConfig.debugMenuEnabled) return;
        _debugTapCount++;
        if (_debugTapCount >= 5) {
          _debugTapCount = 0;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DebugMenuScreen()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Version $_appVersion',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color primaryColor, bool isAuthenticated) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          backgroundImage: ApiService.instance.avatarUrl != null
              ? NetworkImage(ApiService.instance.avatarUrl!)
              : null,
          child: ApiService.instance.avatarUrl == null
              ? Text(
                  isAuthenticated && widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : (isAuthenticated ? 'U' : '?'),
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          isAuthenticated && widget.userName.isNotEmpty
              ? widget.userName
              : (isAuthenticated ? context.l10n.user : context.l10n.guest_mode),
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          isAuthenticated ? widget.userEmail : context.l10n.login_cloud_hint,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(
      Color primaryColor, bool isAuthenticated, SyncStatus status) {
    String syncStatusText;
    IconData syncIcon = Icons.cloud_done;
    Color syncColor = primaryColor;
    bool isSyncing = status == SyncStatus.syncing;

    if (status == SyncStatus.noInternet) {
      syncStatusText = context.l10n.sync_no_internet;
      syncIcon = Icons.cloud_off;
      syncColor = Colors.grey;
    } else if (status == SyncStatus.syncing) {
      syncStatusText = context.l10n.syncing;
      syncIcon = Icons.sync;
      syncColor = Colors.orange;
    } else if (status == SyncStatus.error) {
      syncStatusText = context.l10n.sync_error;
      syncIcon = Icons.error_outline;
      syncColor = Colors.red;
    } else if (status == SyncStatus.success) {
      syncStatusText = context.l10n.sync_updated_just_now;
      syncIcon = Icons.cloud_done;
      syncColor = primaryColor;
    } else {
      syncStatusText = context.l10n.sync_synced;
    }

    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAuthenticated && !isSyncing
            ? context.read<ProfileCubit>().startSync
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isAuthenticated ? syncColor : Colors.grey)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: isAuthenticated && isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: syncColor),
                      )
                    : Icon(isAuthenticated ? syncIcon : Icons.cloud_off,
                        color: isAuthenticated ? syncColor : Colors.grey,
                        size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.sync_status,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      isAuthenticated
                          ? syncStatusText
                          : context.l10n.cloud_not_connected,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isAuthenticated)
                Icon(Icons.sync, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(Color primaryColor) {
    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(context.l10n.dark_mode,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            value: _isDarkMode,
            activeColor: primaryColor,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              PreferencesService.instance.saveDarkMode(val);
            },
          ),
          ListTile(
            title: Text(context.l10n.language,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${LanguageManager.currentLanguage.flag} ${LanguageManager.currentLanguage.displayName}',
                  style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: _showLanguagePicker,
          ),
          ListTile(
            title: Text(context.l10n.currency,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            trailing: ValueListenableBuilder<Currency>(
              valueListenable: CurrencyFormatter.currencyNotifier,
              builder: (context, currency, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currency.localizedName,
                        style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                );
              },
            ),
            onTap: _showCurrencyPicker,
          ),
          SwitchListTile(
            title: Text(context.l10n.notifications,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: Text(context.l10n.limits_and_budgets,
                style: const TextStyle(fontSize: 12)),
            value: _notificationsEnabled,
            activeColor: primaryColor,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              PreferencesService.instance.saveNotificationsEnabled(val);
            },
          ),
        ],
      ),
    );
  }
}
