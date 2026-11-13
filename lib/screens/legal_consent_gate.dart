import 'dart:async';
import 'package:flutter/material.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'terms_update_screen.dart';

/// Следит за статусом документов вошедшего пользователя
/// ([LegalApiService.status]): новая версия соглашения — экран
/// [TermsUpdateScreen] поверх приложения, новая версия политики — шторка
/// [PrivacyUpdateSheet] один раз за запуск.
class LegalConsentGate extends StatefulWidget {
  final Widget child;
  final LegalApiService? service;
  final GlobalKey<NavigatorState>? navigator;

  const LegalConsentGate({
    super.key,
    required this.child,
    this.service,
    this.navigator,
  });

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  late final LegalApiService _service =
      widget.service ?? ApiService.instance.legal;
  late final GlobalKey<NavigatorState> _navigator =
      widget.navigator ?? navigatorKey;

  Route<void>? _termsRoute;
  String? _privacyShownFor;

  @override
  void initState() {
    super.initState();
    _service.status.addListener(_onStatus);
    _onStatus();
  }

  @override
  void dispose() {
    _service.status.removeListener(_onStatus);
    super.dispose();
  }

  /// Навигатор появляется после первого кадра, поэтому действия — после
  /// него. Кадр запрашивается явно: статус меняет ответ сервера, а не
  /// перестройка экрана, и без запроса действие ждало бы любой перерисовки.
  void _onStatus() => WidgetsBinding.instance
    ..addPostFrameCallback((_) => _apply())
    ..ensureVisualUpdate();

  void _apply() {
    if (!mounted) return;
    final navigator = _navigator.currentState;
    if (navigator == null) return;

    if (_service.termsRequired) {
      if (_termsRoute?.isActive ?? false) return;
      final route = TermsUpdateScreen.route();
      _termsRoute = route;
      unawaited(navigator.push(route));
      return;
    }
    if (_service.privacyNoticePending) {
      final version = _service.status.value!.privacyVersion;
      if (_privacyShownFor == version) return;
      _privacyShownFor = version;
      unawaited(_showPrivacyNotice(navigator.context));
    }
  }

  Future<void> _showPrivacyNotice(BuildContext context) async {
    try {
      final versions = await _service.fetchVersions(LanguageManager.code);
      if (!context.mounted || !_service.privacyNoticePending) return;
      final acknowledged =
          await PrivacyUpdateSheet.show(context, versions.privacy);
      if (acknowledged) {
        await _service.accept(privacyVersion: versions.privacy.version);
      }
    } catch (e) {
      // Уведомление не обязательное: покажется при следующем запуске
      AppLogger.w('[LegalConsentGate] Уведомление о политике: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
