import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../utils/utils.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

import '../widgets/widgets.dart';

/// Каркас приложения с нижней навигацией в виде плавающего островка жидкого стекла.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _openProfileTab() {
    setState(() {
      _currentIndex = 3;
    });
  }

  void _logout() {
    context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
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
        String? avatarUrl;
        if (authState is Authenticated) {
          email = authState.email;
          name = authState.name;
          avatarUrl = authState.avatarUrl;
        }

        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<Currency>(
                  valueListenable: CurrencyFormatter.currencyNotifier,
                  builder: (context, currency, _) {
                    return IndexedStack(
                      key: const Key('main_shell_indexed_stack'),
                      index: _currentIndex,
                      children: [
                        DashboardScreen(
                          key: const PageStorageKey('dashboard_tab'),
                          onAuthenticated: (_, __) {},
                          onOpenProfile: _openProfileTab,
                        ),
                        const BudgetsScreen(
                          key: PageStorageKey('budgets_tab'),
                        ),
                        const InsightsScreen(
                          key: PageStorageKey('insights_tab'),
                        ),
                        ProfileScreen(
                          key: const PageStorageKey('profile_tab'),
                          userEmail: email,
                          userName: name,
                          avatarUrl: avatarUrl,
                          onLogout: _logout,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LiquidGlassNavBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    if (_currentIndex != index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    }
                  },
                  destinations: [
                    LiquidGlassNavItem(
                      icon: Icons.wallet_rounded,
                      label: context.l10n.balance,
                    ),
                    LiquidGlassNavItem(
                      icon: Icons.donut_small_rounded,
                      label: context.l10n.limits,
                    ),
                    LiquidGlassNavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: context.l10n.insights,
                    ),
                    LiquidGlassNavItem(
                      icon: Icons.person_rounded,
                      label: context.l10n.profile,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
