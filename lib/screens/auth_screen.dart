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
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '515668069765-se9i0kkcefd93ssb06pusjorjeki73k6.apps.googleusercontent.com',
        );
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final String? idToken = googleAuth.idToken;
        if (idToken == null) {
          throw Exception('Google sign in failed: no ID token returned.');
        }
        await ApiService.instance.loginWithGoogle(idToken);
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

    final googleButton = _SocialButton(
      icon: Image.asset(
        'assets/images/google_logo.png',
        width: 24,
        height: 24,
      ),
      text: context.l10n.login_with_google,
      backgroundColor:
          isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface,
      textColor: colorScheme.onSurface,
      borderColor: colorScheme.outline,
      onPressed: () => _handleSocialLogin('google'),
    );

    final appleButton = _SocialButton(
      icon: FaIcon(FontAwesomeIcons.apple,
          size: 24, color: colorScheme.onPrimary),
      text: context.l10n.login_with_apple,
      backgroundColor: colorScheme.primary,
      textColor: colorScheme.onPrimary,
      borderColor: colorScheme.primary,
      onPressed: () => _handleSocialLogin('apple'),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.account_circle, size: 80, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                context.l10n.login_or_register,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
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
                CircularProgressIndicator(color: colorScheme.primary)
              else if (isIOS)
                appleButton
              else
                googleButton,
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text.rich(
                  TextSpan(
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(text: context.l10n.terms_of_use_prefix),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => launchUrl(
                              Uri.parse(context.l10n.terms_of_use_url)),
                          child: Text(
                            context.l10n.terms_of_use_link,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: context.l10n.terms_of_use_and),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => launchUrl(
                              Uri.parse(context.l10n.privacy_policy_url)),
                          child: Text(
                            context.l10n.privacy_policy_link,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: context.l10n.terms_of_use_suffix),
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
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
