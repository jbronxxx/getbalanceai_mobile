import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../config/legal_links.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Экран входа/регистрации через соцсети (Google, Apple).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  void _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);

    // Проверка интернета перед авторизацией
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppAlerts.noInternet(context);
      }
      return;
    }

    try {
      if (provider == 'google') {
        final nonce = const Uuid().v4();
        await GoogleSignIn.instance.initialize(
          serverClientId: ApiConfig.googleServerClientId,
          nonce: nonce,
        );
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final String? idToken = googleAuth.idToken;
        if (idToken == null) {
          throw Exception('Google sign in failed: no ID token returned.');
        }
        final googlePhoto = googleUser.photoUrl;
        final googleName = googleUser.displayName;
        await ApiService.instance.loginWithGoogle(
          idToken,
          avatarUrl: googlePhoto,
          name: googleName,
        );
        final needAvatarUpdate = googlePhoto != null &&
            googlePhoto.isNotEmpty &&
            googlePhoto != ApiService.instance.avatarUrl;
        final needNameUpdate = googleName != null &&
            googleName.isNotEmpty &&
            (ApiService.instance.userName == null ||
                ApiService.instance.userName!.isEmpty ||
                ApiService.instance.userName ==
                    ApiService.instance.email?.split('@').first);

        if (needAvatarUpdate || needNameUpdate) {
          try {
            await ApiService.instance.updateUserProfile(
              avatarUrl: needAvatarUpdate ? googlePhoto : null,
              name: needNameUpdate ? googleName : null,
            );
          } catch (e) {
            AppLogger.w('[AuthScreen] Ошибка синхронизации профиля Google: $e');
          }
        }
      } else if (provider == 'apple') {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final identityToken = credential.identityToken;
        if (identityToken == null) {
          throw Exception('Apple sign in failed: no identity token returned.');
        }
        await ApiService.instance.loginWithApple(identityToken);
      }

      try {
        await ApiService.instance.syncAll();
      } catch (e) {
        AppLogger.w('Синхронизация после входа не удалась: $e');
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (!mounted) return;
      if (AppErrorHandler.isUserCanceled(e)) {
        AppLogger.i('[AuthScreen] Вход через $provider отменен пользователем');
        return;
      }
      if (e is PlatformException) {
        AppAlerts.showErrorDialog(
          context,
          title: context.l10n.login_error_title,
          message: context.l10n.auth_social_error,
        );
      } else {
        AppErrorHandler.show(
          context,
          e,
          title: context.l10n.login_error_title,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isIOS = theme.platform == TargetPlatform.iOS;
    final isDark = theme.brightness == Brightness.dark;
    final colors = AppColors.of(context);

    final googleButton = _SocialButton(
      icon: Image.asset(
        'assets/images/google_logo.png',
        width: 24,
        height: 24,
      ),
      text: context.l10n.login_with_google,
      backgroundColor: colors.googleButtonBackground,
      textColor: colors.googleButtonText,
      borderColor: isDark
          ? AppColors.highlightBase.withValues(alpha: 0.15)
          : AppColors.highlightBase.withValues(alpha: 0.85),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowBase.withValues(alpha: isDark ? 0.35 : 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      onPressed: () => _handleSocialLogin('google'),
    );

    final appleButton = _SocialButton(
      icon: const FaIcon(
        FontAwesomeIcons.apple,
        size: 24,
        color: AppColors.highlightBase,
      ),
      text: context.l10n.login_with_apple,
      backgroundColor: colors.appleButtonBackground,
      textColor: AppColors.highlightBase,
      borderColor:
          AppColors.highlightBase.withValues(alpha: isDark ? 0.20 : 0.15),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowBase.withValues(alpha: isDark ? 0.40 : 0.15),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      onPressed: () => _handleSocialLogin('apple'),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Мягкое фоновое рассеянное свечение от верхней кромки экрана
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (Navigator.of(context).canPop())
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4.0,
                                    bottom: 4.0,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    color: colorScheme.onSurface,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 16),
                            const SizedBox(height: 16),
                            // Иконка в виде полированного стеклянного медальона
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.brandGradientStart.withValues(
                                        alpha: isDark ? 0.35 : 0.22),
                                    colors.brandGradientEnd.withValues(
                                        alpha: isDark ? 0.45 : 0.28),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.highlightBase
                                      .withValues(alpha: isDark ? 0.22 : 0.70),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.brandGradientStart.withValues(
                                        alpha: isDark ? 0.35 : 0.20),
                                    blurRadius: 24,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.account_circle_rounded,
                                  size: 52,
                                  color: colors.accentText,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.login_or_register,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isIOS
                                  ? context.l10n.continue_with_apple
                                  : context.l10n.continue_with_google,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Spacer(),
                            if (_isLoading)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.accentText,
                                ),
                              )
                            else if (isIOS)
                              appleButton
                            else
                              googleButton,
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text.rich(
                                TextSpan(
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(
                                        text: context.l10n.terms_of_use_prefix),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: GestureDetector(
                                        onTap: () => launchUrl(LegalLinks.url(
                                            LegalPage.terms,
                                            Localizations.localeOf(context)
                                                .languageCode)),
                                        child: Text(
                                          context.l10n.terms_of_use_link,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.of(context)
                                                .accentText,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                        text: context.l10n.terms_of_use_and),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: GestureDetector(
                                        onTap: () => launchUrl(LegalLinks.url(
                                            LegalPage.privacy,
                                            Localizations.localeOf(context)
                                                .languageCode)),
                                        child: Text(
                                          context.l10n.privacy_policy_link,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.of(context)
                                                .accentText,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                        text: context.l10n.terms_of_use_suffix),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка авторизации в стиле Liquid Glass с тонкой световой гранью и тенями.
class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    this.boxShadow,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: AppColors.shadowBase.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: AppFontSize.lead,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: -0.2,
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
}
