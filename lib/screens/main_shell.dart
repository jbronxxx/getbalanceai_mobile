import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

import 'welcome_setup_screen.dart';

/// Каркас приложения с нижней навигацией.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRunLanguageSelection();
    });
  }

  Future<void> _checkFirstRunLanguageSelection() async {
    final isCompleted =
        await PreferencesService.instance.isOnboardingCompleted();
    if (!isCompleted && mounted) {
      WelcomeSetupScreen.show(context);
    }
  }

  void _openProfileTab() {
    setState(() {
      _currentIndex = 3;
    });
  }

  void _logout() {
    context.read<AuthCubit>().logout();
  }

  List<Widget> _getScreens(String email, String name) => [
        DashboardScreen(
          onAuthenticated: (_, __) {},
          onOpenProfile: _openProfileTab,
        ),
        const BudgetsScreen(),
        const InsightsScreen(),
        ProfileScreen(
          userEmail: email,
          userName: name,
          onLogout: _logout,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ValueListenableBuilder<Currency>(
      valueListenable: CurrencyFormatter.currencyNotifier,
      builder: (context, currency, child) {
        return BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is Unauthenticated) {
              setState(() {
                _currentIndex = 0;
              });
            }
          },
          builder: (context, authState) {
            String email = '';
            String name = '';
            if (authState is Authenticated) {
              email = authState.email;
              name = authState.name;
            }

            return Scaffold(
              body: _getScreens(email, name)[_currentIndex],
              bottomNavigationBar: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.wallet_outlined),
                    selectedIcon:
                        Icon(Icons.wallet, color: colorScheme.primary),
                    label: context.l10n.balance,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.pie_chart_outline),
                    selectedIcon:
                        Icon(Icons.pie_chart, color: colorScheme.primary),
                    label: context.l10n.limits,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.lightbulb_outline),
                    selectedIcon:
                        Icon(Icons.lightbulb, color: colorScheme.primary),
                    label: context.l10n.insights,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon:
                        Icon(Icons.person, color: colorScheme.primary),
                    label: context.l10n.profile,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
