import 'package:flutter/material.dart';
import '../services/services.dart';
import '../utils/utils.dart';

/// Экран пошаговой первоначальной настройки языка и базовой валюты.
class WelcomeSetupScreen extends StatefulWidget {
  const WelcomeSetupScreen({super.key});

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
          _selectedCurrency = Currency.rub;
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
    await PreferencesService.instance.setOnboardingCompleted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: colorScheme.onSurface,
                  onPressed: () => _goToStep(0),
                )
              : null,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepIndicator(0, colorScheme),
              const SizedBox(width: 6),
              _buildStepIndicator(1, colorScheme),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
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
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, ColorScheme colorScheme) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 28 : 12,
      height: 4,
      decoration: BoxDecoration(
        color: (isActive || isDone)
            ? colorScheme.primary
            : colorScheme.outlineVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок изолирован сверху, кнопки не прыгают при смене локали
                  SizedBox(
                    height: 64,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        l10n.welcome_lang_title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Кнопки языков в нижней зоне досягаемости пальца
                  ...AppLanguage.values.map((lang) {
                    final isSelected = _selectedLanguage == lang;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 4,
                        ),
                        title: Text(
                          lang.displayName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                                size: 24,
                              )
                            : Icon(
                                Icons.circle_outlined,
                                color: colorScheme.outline,
                                size: 24,
                              ),
                        onTap: () => _onLanguageSelected(lang),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrencyStep(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Лаконичный заголовок "Основная валюта" без дескрипшена
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        l10n.welcome_currency_title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Список валют в нижней комфортной зоне
                  ...Currency.values.map((currency) {
                    final isSelected = _selectedCurrency == currency;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        title: Text(
                          currency.localizedName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                                size: 24,
                              )
                            : Icon(
                                Icons.circle_outlined,
                                color: colorScheme.outline,
                                size: 24,
                              ),
                        onTap: () => _onCurrencySelected(currency),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton(
    ColorScheme colorScheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            if (_currentStep == 0) {
              _goToStep(1);
            } else {
              _finishSetup();
            }
          },
          child: Text(
            l10n.continue_btn,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
