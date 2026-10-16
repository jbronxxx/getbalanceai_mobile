import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/profile/profile_cubit.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/profile/profile.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';

/// Экран профиля пользователя, совмещенный с настройками приложения.
class ProfileScreen extends StatelessWidget {
  final String userEmail;
  final String userName;
  final String? avatarUrl;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    this.avatarUrl,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(),
      child: _ProfileScreenView(
        userEmail: userEmail,
        userName: userName,
        avatarUrl: avatarUrl,
        onLogout: onLogout,
      ),
    );
  }
}

class _ProfileScreenView extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String? avatarUrl;
  final VoidCallback onLogout;

  const _ProfileScreenView({
    required this.userEmail,
    required this.userName,
    this.avatarUrl,
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
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          AppColors.shadowBase.withValues(alpha: isDark ? 0.70 : 0.40),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: GlassContainer(
              borderRadius: 28,
              blurSigma: 18,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary
                          .withValues(alpha: isDark ? 0.16 : 0.12),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: AppColors.of(context).accentText,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
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
    final confirm = await AppAlerts.showConfirmDialog(
      context,
      title: context.l10n.logout_confirm_title,
      message: context.l10n.logout_confirm_desc,
      confirmText: context.l10n.logout,
      cancelText: context.l10n.cancel,
      isDestructive: false,
      icon: Icons.logout_rounded,
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
    final confirm = await AppAlerts.showConfirmDialog(
      context,
      title: context.l10n.delete_account_title,
      message: context.l10n.delete_account_confirm,
      confirmText: context.l10n.delete_account_confirm_btn,
      cancelText: context.l10n.cancel,
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
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
        final authState = context.watch<AuthCubit>().state;
        final isAuthenticated = authState is Authenticated;
        final currentAvatarUrl = authState is Authenticated
            ? authState.avatarUrl
            : (widget.avatarUrl ?? ApiService.instance.avatarUrl);
        final currentUserName =
            authState is Authenticated ? authState.name : widget.userName;
        final currentUserEmail =
            authState is Authenticated ? authState.email : widget.userEmail;

        final scaffoldBg = AppColors.of(context).shellBackground;

        return Scaffold(
          backgroundColor: scaffoldBg,
          resizeToAvoidBottomInset: false,
          extendBodyBehindAppBar: true,
          appBar: LiquidGlassAppBar(
            title: Text(
              context.l10n.profile,
              style: AppTypography.screenTitle(context),
            ),
            centerTitle: true,
          ),
          body: ScreenBodyCard(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: LiquidGlassAppBar.topContentPadding(context) + 24.0,
                  bottom: LiquidGlassNavBar.bottomContentPadding(context),
                ),
                child: Column(
                  children: [
                    ProfileHeader(
                      userName: currentUserName,
                      userEmail: currentUserEmail,
                      avatarUrl: currentAvatarUrl,
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
                    const SizedBox(height: 24),
                    _buildSectionHeader(context.l10n.profile_data_section),
                    const ProfileDataCard(),
                    const SizedBox(height: 24),
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
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.outline,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
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
                    const SizedBox(height: 8),
                    ProfileAppVersion(appVersion: _appVersion),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
