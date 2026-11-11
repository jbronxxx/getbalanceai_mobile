import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../cubits/auth/auth_cubit.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import 'add_transaction_sheet.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';
import 'voice_input_flow.dart';

import '../widgets/widgets.dart';
import '../theme/theme.dart';

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

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    // Тост относится к вкладке, где он появился
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _currentIndex = index);
  }

  /// Форма новой операции открывается с любой вкладки; вкладки узнают
  /// о сохранении через `LocalDbService.transactionsChanged`.
  void _openNewTransaction() => AddTransactionSheet.show(context);

  /// Голосовой ввод — долгое нажатие на «+».
  void _startVoiceInput(bool signedIn) =>
      VoiceInputFlow.start(context, signedIn: signedIn);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowVoiceHint());
  }

  /// Подсказка «удерживайте +» вошедшему пользователю: после первого входа
  /// и затем раз в несколько запусков (см. `takeVoiceHintTurn`).
  Future<void> _maybeShowVoiceHint() async {
    if (!mounted || context.read<AuthCubit>().state is! Authenticated) return;
    if (!await PreferencesService.instance.takeVoiceHintTurn() || !mounted) {
      return;
    }
    // Под экраном блокировки тост никто не увидит — ждём разблокировки
    final locked = AppLockService.instance.locked;
    if (locked.value) {
      final unlocked = Completer<void>();
      void onChange() {
        if (!locked.value && !unlocked.isCompleted) unlocked.complete();
      }

      locked.addListener(onChange);
      await unlocked.future;
      locked.removeListener(onChange);
      if (!mounted) return;
    }
    AppAlerts.showToast(
      context,
      title: context.l10n.voice_input_title,
      message: context.l10n.voice_hint_message,
      duration: voiceHintDuration,
    );
  }

  /// Подсказку успевают прочитать: она длиннее обычного тоста.
  static const voiceHintDuration = Duration(seconds: 7);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          setState(() {
            _currentIndex = 0;
          });
        } else if (state is Authenticated) {
          unawaited(_maybeShowVoiceHint());
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

        final shellBg = AppColors.of(context).shellBackground;

        // Полей ввода во вкладках нет: клавиатура листа операции не должна
        // ни перекладывать, ни перестраивать вкладки и навбар под окном.
        // «Назад» на Android со второстепенной вкладки возвращает на
        // «Баланс», а не закрывает приложение; с «Баланса» — как обычно.
        return PopScope(
          canPop: _currentIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _selectTab(0);
          },
          child: KeyboardInsetsIsolation(
            child: Scaffold(
              backgroundColor: shellBg,
              resizeToAvoidBottomInset: false,
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
                            InsightsScreen(
                              key: const PageStorageKey('insights_tab'),
                              isActive: _currentIndex == 2,
                            ),
                            ProfileScreen(
                              key: const PageStorageKey('profile_tab'),
                              userEmail: email,
                              userName: name,
                              avatarUrl: avatarUrl,
                            ),
                          ]
                              .indexed
                              // Скрытые вкладки остаются в дереве, но их
                              // анимации (лоадер ИИ, подсказки) не тикают.
                              .map((tab) => TickerMode(
                                    enabled: tab.$1 == _currentIndex,
                                    child: tab.$2,
                                  ))
                              .toList(),
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
                      centerAction: LiquidGlassNavAction(
                        tooltip: context.l10n.new_transaction,
                        onPressed: _openNewTransaction,
                        onLongPress: () =>
                            _startVoiceInput(authState is Authenticated),
                        longPressHint: context.l10n.voice_fab_long_press_hint,
                      ),
                      onDestinationSelected: _selectTab,
                      destinations: [
                        LiquidGlassNavItem(
                          icon: Icons.wallet_rounded,
                          label: context.l10n.balance,
                        ),
                        LiquidGlassNavItem(
                          icon: Icons.donut_small_rounded,
                          label: context.l10n.finances,
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
            ),
          ),
        );
      },
    );
  }
}
