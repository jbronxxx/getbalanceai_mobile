import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/profile/profile_cubit.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/profile/profile.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';
import 'account_actions.dart';
import 'add_transaction_sheet.dart';

/// Экран профиля пользователя, совмещенный с настройками приложения.
class ProfileScreen extends StatelessWidget {
  final String userEmail;
  final String userName;
  final String? avatarUrl;

  const ProfileScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(),
      child: _ProfileScreenView(
        userEmail: userEmail,
        userName: userName,
        avatarUrl: avatarUrl,
      ),
    );
  }
}

class _ProfileScreenView extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String? avatarUrl;

  const _ProfileScreenView({
    required this.userEmail,
    required this.userName,
    this.avatarUrl,
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
    } else if (state.syncStatus == SyncStatus.success &&
        state.rejectedSyncCount > 0) {
      AppAlerts.warning(
        context,
        context.l10n.sync_done_with_rejected(state.rejectedSyncCount),
      );
    } else if (state.syncStatus == SyncStatus.success) {
      AppAlerts.success(context, context.l10n.sync_success);
    } else if (state.syncStatus == SyncStatus.error) {
      AppErrorHandler.show(context, state.syncError, title: context.l10n.cloud);
    }
  }

  /// Список операций, которые не принял сервер; выбранная открывается
  /// в форме правки.
  Future<void> _openRejected() async {
    final transaction = await SyncRejectedSheet.show(context);
    if (!mounted || transaction == null) return;
    await AddTransactionSheet.show(context, transactionToEdit: transaction);
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
          previous.syncStatus != current.syncStatus ||
          previous.syncAttempt != current.syncAttempt,
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
                      pendingCount: state.pendingSyncCount,
                      rejectedCount: state.rejectedSyncCount,
                      onSyncPressed: context.read<ProfileCubit>().startSync,
                      onRejectedPressed: _openRejected,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context.l10n.interface),
                    ProfileSettingsCard(
                      onLanguageChanged: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context.l10n.profile_legal_section),
                    const ProfileLegalCard(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: isAuthenticated
                          ? TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => AccountActions.logout(context),
                              child: Text(
                                context.l10n.logout,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                ),
                              ),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/login'),
                              child: Text(
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
                          onPressed: () =>
                              AccountActions.deleteAccount(context),
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
