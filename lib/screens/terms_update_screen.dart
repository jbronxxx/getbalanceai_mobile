import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/legal_links.dart';
import '../cubits/profile/profile_cubit.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'account_actions.dart';

/// Экран новой версии пользовательского соглашения. Пока версия не принята,
/// сервер закрывает данные аккаунта (`403 TERMS_NOT_ACCEPTED`), поэтому экран
/// не закрывается жестом «назад»: только «Принять», выход или удаление
/// аккаунта. Сам закрывается, когда соглашение принято или сессия завершена.
class TermsUpdateScreen extends StatefulWidget {
  const TermsUpdateScreen({super.key});

  static const routeName = '/terms-update';

  static Route<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const TermsUpdateScreen(),
      );

  @override
  State<TermsUpdateScreen> createState() => _TermsUpdateScreenState();
}

class _TermsUpdateScreenState extends State<TermsUpdateScreen> {
  final ApiService _api = ApiService.instance;

  LegalVersions? _versions;
  bool _failed = false;
  bool _accepting = false;

  LegalApiService get _legal => _api.legal;

  @override
  void initState() {
    super.initState();
    _legal.status.addListener(_closeWhenResolved);
    unawaited(_load());
  }

  @override
  void dispose() {
    _legal.status.removeListener(_closeWhenResolved);
    super.dispose();
  }

  /// Соглашение принято (здесь или на другом устройстве) или сессия
  /// завершена: экран убирается, даже если поверх него открыт диалог.
  void _closeWhenResolved() {
    if (_legal.termsRequired || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  /// Версии с «Что изменилось» и точный статус: после `403` известно только,
  /// что соглашение не принято, а не изменилась ли и политика.
  Future<void> _load() async {
    setState(() {
      _failed = false;
      _versions = null;
    });
    try {
      final results = await Future.wait([
        _legal.fetchVersions(LanguageManager.code),
        _api.auth.refreshProfile(),
      ]);
      if (!mounted) return;
      setState(() => _versions = results.first as LegalVersions);
    } catch (e) {
      AppLogger.w('[TermsUpdate] Не удалось загрузить версии документов: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _privacyPending => _legal.status.value?.privacyAccepted == false;

  Future<void> _accept() async {
    final versions = _versions;
    if (versions == null) return;
    setState(() => _accepting = true);
    try {
      await _legal.accept(
        termsVersion: versions.terms.version,
        privacyVersion: _privacyPending ? versions.privacy.version : null,
      );
      // Пока соглашение не было принято, сервер не принимал изменения
      unawaited(_api.syncAll().then<void>((_) {}, onError: (Object e) {
        AppLogger.w('[TermsUpdate] Синхронизация после принятия: $e');
      }));
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      if (data is Map && data['code'] == 'LEGAL_VERSION_OUTDATED') {
        AppAlerts.warning(context, context.l10n.legal_version_outdated);
        unawaited(_load());
      } else {
        AppErrorHandler.show(context, e);
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocProvider(
        create: (_) => ProfileCubit(api: _api),
        child: Builder(builder: _buildScreen),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final versions = _versions;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WholeWordsText(
                      context.l10n.terms_update_title,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (versions != null)
                      ..._buildChanges(context, versions)
                    else if (_failed)
                      _buildLoadError(context)
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetPrimaryButton(
                    key: const ValueKey('terms_accept_button'),
                    label: context.l10n.legal_accept_btn,
                    busy: _accepting,
                    onPressed: versions == null || _accepting ? null : _accept,
                  ),
                  const SizedBox(height: 12),
                  SheetOutlinedButton(
                    key: const ValueKey('terms_logout_button'),
                    label: context.l10n.logout,
                    onPressed: _accepting
                        ? null
                        : () => AccountActions.logout(context),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      key: const ValueKey('terms_delete_account_button'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.outline,
                      ),
                      onPressed: _accepting
                          ? null
                          : () => AccountActions.deleteAccount(context),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Пункты соглашения, а если не принята и новая политика — и её: тогда
  /// у каждого блока подзаголовок с названием документа.
  List<Widget> _buildChanges(BuildContext context, LegalVersions versions) {
    final both = _privacyPending;
    return [
      LegalChanges(
        info: versions.terms,
        page: LegalPage.terms,
        heading: both ? context.l10n.terms_of_use_title : null,
      ),
      if (both) ...[
        const SizedBox(height: 24),
        LegalChanges(
          info: versions.privacy,
          page: LegalPage.privacy,
          heading: context.l10n.privacy_policy_title,
        ),
      ],
    ];
  }

  Widget _buildLoadError(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WholeWordsText(
          context.l10n.legal_load_error,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SheetOutlinedButton(
          key: const ValueKey('terms_retry_button'),
          label: context.l10n.service_unavailable_retry,
          onPressed: _load,
        ),
      ],
    );
  }
}
