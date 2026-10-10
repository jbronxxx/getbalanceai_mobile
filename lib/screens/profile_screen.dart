import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/profile/profile_cubit.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/profile/profile.dart';
import '../widgets/widgets.dart';

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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
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

  void _handleSyncState(BuildContext context, ProfileState state) {
    if (state.syncStatus == SyncStatus.noInternet) {
      AppAlerts.noInternet(context);
    } else if (state.syncStatus == SyncStatus.success) {
      AppAlerts.success(context, context.l10n.sync_success);
    } else if (state.syncStatus == SyncStatus.error) {
      AppErrorHandler.show(context, state.syncError, title: context.l10n.cloud);
    }
  }

  void _showLoadingDialog(String message) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.logout_confirm_title),
        content: Text(context.l10n.logout_confirm_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    _showLoadingDialog(context.l10n.logging_out);
    await cubit.logout();
    if (!mounted) return;
    Navigator.pop(context);

    widget.onLogout();
    AppAlerts.info(context, context.l10n.logout_info);
  }

  Future<void> _handleDeleteAccount() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.delete_account_title),
        content: Text(context.l10n.delete_account_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text(context.l10n.delete_account_confirm_btn),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _showLoadingDialog(context.l10n.deleting);
      try {
        await ApiService.instance.deleteAccount();
        if (mounted) {
          Navigator.pop(context);
          widget.onLogout();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          AppErrorHandler.show(context, e,
              title: context.l10n.delete_account_error);
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.outline,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

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
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(
              context.l10n.profile,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
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
                  ProfileHeader(
                    userName: widget.userName,
                    userEmail: widget.userEmail,
                    isAuthenticated: isAuthenticated,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context.l10n.cloud),
                  ProfileSyncCard(
                    isAuthenticated: isAuthenticated,
                    status: state.syncStatus,
                    onSyncPressed: context.read<ProfileCubit>().startSync,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context.l10n.interface),
                  ProfileSettingsCard(
                    onLanguageChanged: () {
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: isAuthenticated
                        ? TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout),
                            label: Text(
                              context.l10n.logout,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.error,
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/login'),
                            icon: const Icon(Icons.login),
                            label: Text(
                              context.l10n.login_or_register,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                  ),
                  if (isAuthenticated) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.outline,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _handleDeleteAccount,
                        child: Text(
                          context.l10n.delete_account_btn,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ProfileAppVersion(appVersion: _appVersion),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
