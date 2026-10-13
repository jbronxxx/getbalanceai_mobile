import 'dart:async';
import 'package:flutter/material.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Экран пошаговой первоначальной настройки языка и базовой валюты.
class WelcomeSetupScreen extends StatefulWidget {
  final VoidCallback? onFinish;

  const WelcomeSetupScreen({
    super.key,
    this.onFinish,
  });

  /// Открывает экран в полноэкранном режиме.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const WelcomeSetupScreen(),
      ),
    );
  }

  @override
  State<WelcomeSetupScreen> createState() => _WelcomeSetupScreenState();
}

class _WelcomeSetupScreenState extends State<WelcomeSetupScreen> {
  late final PageController _pageController;
  int _currentStep = 0;

  late AppLanguage _selectedLanguage;
  late Currency _selectedCurrency;
  bool _currencyManuallyChanged = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedLanguage = LanguageManager.currentLanguage;
    _selectedCurrency = CurrencyFormatter.currentCurrency;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onLanguageSelected(AppLanguage lang) {
    setState(() {
      _selectedLanguage = lang;
      LanguageManager.setLanguage(lang, save: false);
      if (!_currencyManuallyChanged) {
        if (lang == AppLanguage.uz) {
          _selectedCurrency = Currency.uzs;
        } else if (lang == AppLanguage.ru) {
          _selectedCurrency = Currency.usd;
        } else if (lang == AppLanguage.en) {
          _selectedCurrency = Currency.usd;
        }
      }
    });
  }

  void _onCurrencySelected(Currency currency) {
    setState(() {
      _currencyManuallyChanged = true;
      _selectedCurrency = currency;
    });
  }

  Future<void> _finishSetup() async {
    await PreferencesService.instance.saveLanguage(_selectedLanguage.code);
    CurrencyFormatter.setCurrency(_selectedCurrency);
    if (ApiService.instance.isAuthenticated) {
      unawaited(
        ApiService.instance
            .updateUserProfile(baseCurrency: _selectedCurrency.code),
      );
    }
    await PreferencesService.instance.setOnboardingCompleted();
    if (mounted) {
      if (widget.onFinish != null) {
        widget.onFinish!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0) {
          _goToStep(0);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
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
                      colorScheme.primary
                          .withValues(alpha: isDark ? 0.20 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildLanguageStep(
                          context,
                          theme,
                          colorScheme,
                          textTheme,
                          l10n,
                        ),
                        _buildCurrencyStep(
                          context,
                          theme,
                          colorScheme,
                          textTheme,
                          l10n,
                        ),
                      ],
                    ),
                  ),
                  _buildBottomButton(colorScheme, textTheme, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageStep(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final glassTheme = GlassTheme.of(context);
    final primaryColor = colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.welcome_lang_title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcome_lang_subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          ...AppLanguage.values.map((lang) {
            final isSelected = _selectedLanguage == lang;
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 20,
              blurSigma: 16,
              color: isSelected
                  ? primaryColor.withValues(alpha: isDark ? 0.24 : 0.12)
                  : glassTheme.surface,
              border: Border.all(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.85)
                    : glassTheme.rim,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? primaryColor.withValues(alpha: isDark ? 0.35 : 0.20)
                      : glassTheme.shadow,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
              ],
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _onLanguageSelected(lang),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    title: Text(
                      lang.displayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color:
                            isSelected ? primaryColor : colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: 0.20),
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                          )
                        : Icon(
                            Icons.circle_outlined,
                            color: colorScheme.outline,
                            size: 22,
                          ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCurrencyStep(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final glassTheme = GlassTheme.of(context);
    final primaryColor = colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: colorScheme.onSurface,
              onPressed: () => _goToStep(0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcome_currency_title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcome_currency_subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                ...Currency.values.map((currency) {
                  final isSelected = _selectedCurrency == currency;
                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    borderRadius: 20,
                    blurSigma: 16,
                    color: isSelected
                        ? primaryColor.withValues(alpha: isDark ? 0.24 : 0.12)
                        : glassTheme.surface,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.85)
                          : glassTheme.rim,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? primaryColor.withValues(
                                alpha: isDark ? 0.35 : 0.20)
                            : glassTheme.shadow,
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                        spreadRadius: -2,
                      ),
                    ],
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _onCurrencySelected(currency),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 2,
                          ),
                          title: Text(
                            currency.localizedName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? primaryColor
                                  : colorScheme.onSurface,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor.withValues(alpha: 0.20),
                                  ),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: colorScheme.outline,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
    ColorScheme colorScheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassContainer(
        borderRadius: 18,
        blurSigma: 16,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (_currentStep == 0) {
                _goToStep(1);
              } else {
                _finishSetup();
              }
            },
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(
                child: Text(
                  l10n.continue_btn,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
